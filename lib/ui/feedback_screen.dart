import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _subject;
  bool _sending = false;

  static const List<String> _subjects = <String>[
    'Bug',
    'Suggestion',
    'Issue',
  ];

  bool get _canSubmit => !_sending && _messageController.text.trim().isNotEmpty;

  Future<void> _sendFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_canSubmit) return;

    setState(() => _sending = true);
    try {
      final session = context.read<CaseContext>();
      final currentScreen =
          ModalRoute.of(context)?.settings.name ?? 'feedback_screen';

      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.uid,
        'message': _messageController.text.trim(),
        'subject': _subject,
        'createdAt': FieldValue.serverTimestamp(),
        'currentScreen': currentScreen,
        'role': session.isAttorney ? 'attorney' : 'parent',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thanks — your feedback helps us improve ParentLedger.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send feedback: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Send Feedback'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us what would make ParentLedger better.',
                style: PLDesign.body,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _subject,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                ),
                items: _subjects
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: _sending ? null : (value) => setState(() => _subject = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                enabled: !_sending,
                minLines: 6,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Describe the bug, idea, or issue...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _sendFeedback : null,
                  child: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Feedback'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
