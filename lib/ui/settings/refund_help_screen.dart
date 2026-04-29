import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/design.dart';

class RefundHelpScreen extends StatefulWidget {
  const RefundHelpScreen({super.key});

  @override
  State<RefundHelpScreen> createState() => _RefundHelpScreenState();
}

class _RefundHelpScreenState extends State<RefundHelpScreen> {
  final _noteController = TextEditingController();
  bool _loadingSupport = false;
  bool _loadingPlay = false;

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static const String _supportEmail = 'support@parentledgerinfo.com';

  _RefundText get _t {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    return lang == 'es' ? _RefundText.es() : _RefundText.en();
  }

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'refund_help_opened');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> openPlaySubscriptions() async {
    final confirmed = await _confirmOpenPlay();
    if (confirmed != true) return;
    if (_loadingPlay) return;
    setState(() => _loadingPlay = true);
    const playUri = 'https://play.google.com/store/account/subscriptions';
    final uri = Uri.parse(playUri);
    try {
      await _analytics.logEvent(name: 'refund_play_store_opened');
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t.playOpenFallback)),
        );
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.playOpenFallback)),
      );
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } finally {
      if (mounted) setState(() => _loadingPlay = false);
    }
  }

  Future<void> _contactSupport() async {
    if (_loadingSupport) return;
    setState(() => _loadingSupport = true);
    await _analytics.logEvent(name: 'refund_contact_support_clicked');

    final user = FirebaseAuth.instance.currentUser;
    final note = _noteController.text.trim();
    final appInfo = await PackageInfo.fromPlatform();
    final platform = Platform.operatingSystem;
    final userEmail = user?.email ?? '';
    final userId = user?.uid ?? '';
    final fallbackBody =
        'User ID: $userId\nEmail: $userEmail\nApp Version: ${appInfo.version}+${appInfo.buildNumber}\nPlatform: $platform\nIssue: refund_request\nNote: ${note.isEmpty ? 'N/A' : note}';

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendSupportEmail');
      await callable.call(<String, dynamic>{
        'userId': userId,
        'email': userEmail,
        'issue': 'refund_request',
        'message': note,
        'appVersion': '${appInfo.version}+${appInfo.buildNumber}',
        'platform': platform,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.supportRequestSent)),
      );
    } catch (_) {
      final mailto = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {
          'subject': 'Refund Request',
          'body': fallbackBody,
        },
      );
      final launched = await launchUrl(mailto);
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t.supportRequestFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSupport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(_t.title),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: PLDesign.gradientCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💳', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      _t.subtitle,
                      style: PLDesign.body.copyWith(fontSize: 14, height: 1.35),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _t.explainer,
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PLDesign.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PLDesign.border),
            ),
            child: Text(
              _t.policyCard,
              style: PLDesign.caption.copyWith(height: 1.35),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: PLDesign.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: PLDesign.softShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _loadingPlay ? null : openPlaySubscriptions,
                child: Center(
                  child: _loadingPlay
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _t.openSubscriptionSettings,
                          style: PLDesign.buttonText,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _t.deniedMessage,
            style: PLDesign.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _t.noteLabel,
              filled: true,
              fillColor: PLDesign.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: PLDesign.border),
              ),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _loadingSupport ? null : _contactSupport,
            icon: const Text('🛟'),
            label: _loadingSupport
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_t.contactSupport),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmOpenPlay() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t.confirmTitle),
        content: Text(_t.confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t.continueText),
          ),
        ],
      ),
    );
  }
}

class _RefundText {
  const _RefundText({
    required this.title,
    required this.subtitle,
    required this.explainer,
    required this.policyCard,
    required this.openSubscriptionSettings,
    required this.deniedMessage,
    required this.noteLabel,
    required this.contactSupport,
    required this.playOpenFallback,
    required this.supportRequestSent,
    required this.supportRequestFailed,
    required this.confirmTitle,
    required this.confirmBody,
    required this.cancel,
    required this.continueText,
  });

  final String title;
  final String subtitle;
  final String explainer;
  final String policyCard;
  final String openSubscriptionSettings;
  final String deniedMessage;
  final String noteLabel;
  final String contactSupport;
  final String playOpenFallback;
  final String supportRequestSent;
  final String supportRequestFailed;
  final String confirmTitle;
  final String confirmBody;
  final String cancel;
  final String continueText;

  factory _RefundText.en() => const _RefundText(
        title: 'Need a refund?',
        subtitle: 'Subscriptions are handled securely by Google Play.',
        explainer:
            'You can request a refund directly through Google Play in just a few taps.',
        policyCard: 'Refund approval is determined by Google Play policies.',
        openSubscriptionSettings: 'Open Subscription Settings',
        deniedMessage:
            'If your request is denied, contact us and we\'ll make it right.',
        noteLabel: 'Add a note (optional)',
        contactSupport: 'Contact Support',
        playOpenFallback: "Couldn't open Play Store. Opening in browser.",
        supportRequestSent: 'Support request sent.',
        supportRequestFailed:
            'Something went wrong. Please email support@parentledgerinfo.com',
        confirmTitle: 'Open Google Play?',
        confirmBody:
            'You are about to open Google Play subscription settings to request a refund.',
        cancel: 'Cancel',
        continueText: 'Continue',
      );

  factory _RefundText.es() => const _RefundText(
        title: 'Necesitas un reembolso?',
        subtitle:
            'Las suscripciones se gestionan de forma segura por Google Play.',
        explainer:
            'Puedes solicitar un reembolso directamente en Google Play en unos pocos pasos.',
        policyCard:
            'La aprobacion del reembolso depende de las politicas de Google Play.',
        openSubscriptionSettings: 'Abrir ajustes de suscripcion',
        deniedMessage:
            'Si tu solicitud es rechazada, contactanos y te ayudaremos.',
        noteLabel: 'Agregar una nota (opcional)',
        contactSupport: 'Contactar soporte',
        playOpenFallback:
            'No se pudo abrir Google Play. Abriendo en el navegador.',
        supportRequestSent: 'Solicitud enviada a soporte.',
        supportRequestFailed:
            'Algo salio mal. Escribe a support@parentledgerinfo.com',
        confirmTitle: 'Abrir Google Play?',
        confirmBody:
            'Vas a abrir los ajustes de suscripcion de Google Play para solicitar un reembolso.',
        cancel: 'Cancelar',
        continueText: 'Continuar',
      );
}
