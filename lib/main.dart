import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/context_l10n.dart';
import 'l10n/tone_string_resolver.g.dart';

import 'package:firebase_core/firebase_core.dart';
import 'config/env.dart';
import 'ui/help_center_screen.dart';
import 'ui/route_case_guard.dart';
import 'ui/splash_screen.dart';
import 'firebase_options.dart';
import 'providers/case_context.dart';
import 'providers/tone_preference.dart';
import 'design/design.dart';
import 'services/invite_link_service.dart';
import 'services/case_switcher_service.dart';
import 'services/app_check_bootstrap.dart';
import 'services/crashlytics_service.dart';
import 'services/revenuecat_service.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    logGoogleApiKeyDebug();
    if (kDebugMode) {
      try {
        validateApiKey();
      } on Exception {
        debugPrint('Places API key validation failed');
      }
    }

    var firebaseReady = false;
    for (var attempt = 0; attempt < 2 && !firebaseReady; attempt++) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseReady = true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Firebase.initializeApp failed (attempt ${attempt + 1}): $e',
          );
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    }

    if (firebaseReady) {
      await CrashlyticsService.bootstrap();
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      await AppCheckBootstrap.activateIfNeeded();
    } else if (kDebugMode) {
      debugPrint('Firebase unavailable at startup; app will still render.');
    }

    try {
      await RevenueCatService.configure();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RevenueCat configure failed: $e');
      }
      if (firebaseReady) {
        await CrashlyticsService.recordError(
          e,
          st,
          reason: 'RevenueCat.configure',
        );
      }
    }

    try {
      await InviteLinkService.start();
    } catch (e) {
      if (kDebugMode) debugPrint('Invite link service failed: $e');
    }

    runApp(AppBootstrap(firebaseAvailable: firebaseReady));
  }, (Object error, StackTrace stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Crashlytics not available (e.g. Firebase not initialized).
    }
  });
}

class AppBootstrap extends StatelessWidget {
  final bool firebaseAvailable;

  const AppBootstrap({super.key, required this.firebaseAvailable});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TonePreference()),
        if (firebaseAvailable) ...[
          ChangeNotifierProvider(
            create: (_) {
              final sub = SubscriptionService();
              sub.start();
              return sub;
            },
          ),
          ChangeNotifierProvider(
            create: (context) {
              final sub =
                  Provider.of<SubscriptionService>(context, listen: false);
              final session = CaseContext(subscriptionService: sub);
              session.start();
              return session;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final switcher = CaseSwitcherService();
              switcher.start();
              return switcher;
            },
          ),
        ],
      ],
      child: firebaseAvailable
          ? const ParentLedgerApp()
          : const _StartupFailureApp(),
    );
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) {
        try {
          final loc = AppLocalizations.of(context);
          final tone = Provider.of<TonePreference>(context, listen: false).tone;
          return toneString(loc, 'appName', tone);
        } catch (_) {
          return 'ParentLedger';
        }
      },
      theme: appTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Builder(
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    context.tTone('startupConnectionIssue'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tTone('startupFailureBody'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ParentLedgerApp extends StatefulWidget {
  const ParentLedgerApp({super.key});

  @override
  State<ParentLedgerApp> createState() => _ParentLedgerAppState();
}

class _ParentLedgerAppState extends State<ParentLedgerApp> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tonePrefs = context.read<TonePreference>();
    try {
      final remote = context.read<CaseContext>().userUxTone;
      tonePrefs.hydrateFromFirestore(remote);
    } catch (_) {
      // CaseContext not registered
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) {
        try {
          final loc = AppLocalizations.of(context);
          final tone = Provider.of<TonePreference>(context, listen: false).tone;
          return toneString(loc, 'appName', tone);
        } catch (_) {
          return 'ParentLedger';
        }
      },
      theme: appTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        for (final locale in supportedLocales) {
          if (locale.languageCode == deviceLocale?.languageCode) {
            return locale;
          }
        }
        return supportedLocales.first;
      },
      home: const SplashScreen(),
      routes: <String, WidgetBuilder>{
        '/help': (_) => const HelpCenterScreen(),
      },
      onGenerateRoute: CaseRoutes.onGenerateRoute,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
