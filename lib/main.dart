import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/tone_string_resolver.g.dart';

import 'package:firebase_core/firebase_core.dart';
import 'config/env.dart';
import 'ui/dashboard_screen.dart';
import 'ui/help_center_screen.dart';
import 'ui/route_case_guard.dart';
import 'ui/splash_screen.dart';
import 'firebase_options.dart';
import 'providers/case_context.dart';
import 'providers/tone_preference.dart';
import 'design/design.dart';
import 'services/invite_link_service.dart';
import 'ui/invite/invite_accept_named_route.dart';
import 'services/case_switcher_service.dart';
import 'services/revenuecat_service.dart';
import 'services/subscription_service.dart';
import 'startup_diag.dart';

/// Temporary: skip Purchases bootstrap until Firebase init is stable (isolate failures).
const bool _kTempSkipRevenueCatBootstrap = true;

/// Always logs to console during Firebase bootstrap so failures are visible in `flutter run`.
void _firebaseBootstrapLog(String message) {
  debugPrint('[FirebaseBootstrap] $message');
}

void _logDefaultFirebaseOptionsSnapshot() {
  try {
    final o = DefaultFirebaseOptions.currentPlatform;
    _firebaseBootstrapLog(
      'DefaultFirebaseOptions.currentPlatform → '
      'projectId=${o.projectId} '
      'appId=${o.appId} '
      'messagingSenderId=${o.messagingSenderId} '
      'apiKeyLen=${o.apiKey.length} '
      'storageBucket=${o.storageBucket}',
    );
    final ok = o.projectId.isNotEmpty &&
        o.appId.isNotEmpty &&
        o.apiKey.isNotEmpty &&
        o.messagingSenderId.isNotEmpty;
    _firebaseBootstrapLog('DefaultFirebaseOptions non-empty check: $ok');
  } catch (e, st) {
    _firebaseBootstrapLog('DefaultFirebaseOptions snapshot FAILED: $e\n$st');
  }
}

Future<void> _initializeFirebase() async {
  const maxAttempts = 3;

  _firebaseBootstrapLog('_initializeFirebase() start');
  _firebaseBootstrapLog(
    'Firebase.apps.length (before init)=${Firebase.apps.length}',
  );
  for (final app in Firebase.apps) {
    _firebaseBootstrapLog('existing FirebaseApp name="${app.name}" options.appId=${app.options.appId}');
  }

  if (Firebase.apps.isNotEmpty) {
    _firebaseBootstrapLog(
      'Skipping Firebase.initializeApp — already initialized (single-init guard)',
    );
    return;
  }

  _logDefaultFirebaseOptionsSnapshot();

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      _firebaseBootstrapLog(
        'Firebase.initializeApp() attempt $attempt/$maxAttempts '
        '(options: DefaultFirebaseOptions.currentPlatform)',
      );
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseBootstrapLog(
        'Firebase.initializeApp() SUCCESS — '
        'Firebase.apps.length=${Firebase.apps.length}',
      );
      if (Firebase.apps.isNotEmpty) {
        _firebaseBootstrapLog(
          'default app: ${Firebase.app().name} appId=${Firebase.app().options.appId}',
        );
      }
      startupDiag('_initializeFirebase', 'success');
      return;
    } catch (e, st) {
      _firebaseBootstrapLog('Firebase.initializeApp() FAILED on attempt $attempt');
      _firebaseBootstrapLog('EXCEPTION TYPE: ${e.runtimeType}');
      _firebaseBootstrapLog('EXCEPTION: $e');
      _firebaseBootstrapLog('STACK TRACE:\n$st');

      if (e is PlatformException) {
        _firebaseBootstrapLog(
          'PlatformException code=${e.code} message=${e.message} details=${e.details}',
        );
      }
      if (e is FirebaseException) {
        _firebaseBootstrapLog(
          'FirebaseException code=${e.code} plugin=${e.plugin} message=${e.message}',
        );
      }

      final isChannelError = e is PlatformException &&
          (e.code == 'channel-error' ||
              (e.message?.contains('Unable to establish connection on channel') ??
                  false));

      if (!isChannelError || attempt == maxAttempts) {
        _firebaseBootstrapLog('Rethrowing after logging (not retrying or max attempts reached)');
        rethrow;
      }

      _firebaseBootstrapLog(
        'channel-error — retry after ${250 * attempt}ms (attempt $attempt/$maxAttempts)',
      );
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
}

/// Ensures one frame is flushed before [Firebase.initializeApp] so the Android
/// FlutterFirebaseCore plugin channel is attached (mitigates `channel-error`).
Future<void> _initializeFirebaseAfterFirstFrame() async {
  await WidgetsBinding.instance.endOfFrame;
  _firebaseBootstrapLog(
    'WidgetsBinding.instance.endOfFrame OK — calling _initializeFirebase',
  );
  await _initializeFirebase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _firebaseBootstrapLog('WidgetsFlutterBinding.ensureInitialized() OK');
  startupDiag('main', 'ensureInitialized → runApp(_StartupGateApp)');
  runApp(const _StartupGateApp());
}

class _StartupGateApp extends StatefulWidget {
  const _StartupGateApp();

  @override
  State<_StartupGateApp> createState() => _StartupGateAppState();
}

class _StartupGateAppState extends State<_StartupGateApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeFirebaseAfterFirstFrame();
  }

  void _retry() {
    setState(() {
      _initFuture = _initializeFirebaseAfterFirstFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          startupDiag('_StartupGateApp', 'waiting Firebase FutureBuilder');
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          startupDiag('_StartupGateApp', 'Firebase init error → error UI');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 44),
                      const SizedBox(height: 12),
                      const Text(
                        'Startup failed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Could not initialize Firebase. Tap retry.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        startupDiag('_StartupGateApp', 'Firebase OK → AppBootstrap');
        return const AppBootstrap();
      },
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    startupDiag('AppBootstrap', 'initState → RC + invites (async)');
    unawaited(_initializeNonFirebaseServices());
  }

  Future<void> _initializeNonFirebaseServices() async {
    startupDiag('AppBootstrap._initializeNonFirebaseServices', 'begin');
    logGoogleApiKeyDebug();
    if (kDebugMode) {
      try {
        validateApiKey();
      } on Exception {
        debugPrint('Places API key validation failed');
      }
    }

    if (_kTempSkipRevenueCatBootstrap) {
      _firebaseBootstrapLog(
        'TEMP: skipping RevenueCatService.configure (Firebase isolation)',
      );
    } else {
      try {
        await RevenueCatService.configure();
      } catch (e, st) {
        debugPrint('RevenueCat configure failed: $e\n$st');
      }
    }

    try {
      startupDiag('AppBootstrap', 'InviteLinkService.start');
      await InviteLinkService.start();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('InviteLinkService.start failed: $e');
      }
    }
    startupDiag('AppBootstrap._initializeNonFirebaseServices', 'end');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TonePreference()),
        ChangeNotifierProvider(
          create: (_) {
            final sub = SubscriptionService();
            sub.start();
            return sub;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final sub = context.read<SubscriptionService>();
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
      child: const ParentLedgerApp(),
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
    try {
      final tonePrefs = context.read<TonePreference>();
      try {
        final remote = context.read<CaseContext>().userUxTone;
        tonePrefs.hydrateFromFirestore(remote);
      } catch (_) {
        // CaseContext not registered (e.g. firebase init failed)
      }
    } catch (_) {
      // TonePreference unavailable — must never crash app startup.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) {
        try {
          final loc = AppLocalizations.of(context);
          final tone = context.read<TonePreference>().tone;
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
        '/dashboard': (_) => const DashboardScreen(),
        '/accept-invite': (_) => const InviteAcceptNamedRoute(),
      },
      onGenerateRoute: CaseRoutes.onGenerateRoute,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
