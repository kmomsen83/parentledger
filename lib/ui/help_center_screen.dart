import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/design.dart';
import 'ai_assistant_screen.dart';

/// Entry point for help, FAQs, and future support channels.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static Uri _supportMail() => Uri.parse(
        'mailto:support@parentledgerinfo.com?subject=${Uri.encodeComponent('ParentLedger support')}',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('helpSupport')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: PLDesign.gradientCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We’re here to help', style: PLDesign.heroTitle.copyWith(fontSize: 24)),
                const SizedBox(height: 10),
                Text(
                  'Get answers, contact support, or start a conversation. '
                  'Live chat and in-app AI help can plug in here later.',
                  style: PLDesign.body.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _tile(
            context,
            icon: Icons.mail_outline_rounded,
            title: 'Email support',
            subtitle: 'We typically respond within one business day',
            onTap: () async {
              final ok = await launchUrl(_supportMail());
              if (!context.mounted || ok) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tTone('couldNotOpenEmailApp'))),
              );
            },
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.quiz_outlined,
            title: 'FAQs',
            subtitle: 'Common questions about custody records and billing',
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: PLDesign.card,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text('FAQs', style: PLDesign.sectionTitle),
                      const SizedBox(height: 16),
                      Text(
                        '• Timeline entries are time-stamped when saved.\n'
                        '• Exports compile what you already logged — they are not legal advice.\n'
                        '• Subscription is managed in the App Store or Google Play.\n'
                        '• Co-parents and counsel can be invited from Profile.',
                        style: PLDesign.body.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.smart_toy_outlined,
            title: 'AI assistant',
            subtitle: 'Ask about features, exports, invites, messages, timeline, or next steps',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AiAssistantScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: PLDesign.legalGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xff26324d)),
            boxShadow: PLDesign.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Icon(icon, color: PLDesign.primary, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: PLDesign.caption.copyWith(height: 1.3)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: PLDesign.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
