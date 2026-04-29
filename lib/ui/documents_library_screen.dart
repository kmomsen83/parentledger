import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/case_document_type.dart';
import '../providers/case_context.dart';
import '../services/case_document_service.dart';

class DocumentsLibraryScreen extends StatefulWidget {
  const DocumentsLibraryScreen({super.key});

  @override
  State<DocumentsLibraryScreen> createState() => _DocumentsLibraryScreenState();
}

class _DocumentsLibraryScreenState extends State<DocumentsLibraryScreen> {
  bool _uploading = false;

  Future<void> _upload(BuildContext context, String? caseId) async {
    if (caseId == null) return;
    final type = await showModalBottomSheet<CaseDocumentType>(
      context: context,
      backgroundColor: PLDesign.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Document type', style: PLDesign.sectionTitle),
                const SizedBox(height: 12),
                ...CaseDocumentType.values.map(
                  (t) => ListTile(
                    title: Text(t.label),
                    onTap: () => Navigator.pop(ctx, t),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (type == null || !context.mounted) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final path = f.path;
    if (path == null) return;
    final name = f.name;

    setState(() => _uploading = true);
    try {
      await CaseDocumentService.uploadDocument(
        caseId: caseId,
        file: File(path),
        fileName: name,
        type: type,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tTone('documentUploaded'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;
    final df = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('caseDocuments')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
        actions: [
          if (_uploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Upload',
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: caseId == null ? null : () => _upload(context, caseId),
            ),
        ],
      ),
      body: caseId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No case linked. Complete setup to manage documents.',
                  style: PLDesign.body.copyWith(height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: CaseDocumentService.watchDocuments(caseId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '${snap.error}',
                      style: PLDesign.body.copyWith(color: PLDesign.danger),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 56,
                            color: PLDesign.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No documents yet',
                            style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload court orders, agreements, or evidence files. '
                            'Each file is stored with a server timestamp and uploader id.',
                            style: PLDesign.caption.copyWith(height: 1.35),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _upload(context, caseId),
                            icon: const Icon(Icons.add),
                            label: Text(context.tTone('uploadDocument')),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final name = (d['fileName'] ?? 'Document').toString();
                    final url = (d['fileUrl'] ?? '').toString();
                    final type = CaseDocumentType.fromFirestore(d['type']);
                    final uploaded = d['uploadedAt'];
                    String when = '—';
                    if (uploaded is Timestamp) {
                      when = df.format(uploaded.toDate());
                    }

                    return Material(
                      color: PLDesign.card,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: PLDesign.primary.withValues(alpha: 0.15),
                          child: Icon(
                            type == CaseDocumentType.courtOrder
                                ? Icons.gavel_rounded
                                : type == CaseDocumentType.agreement
                                    ? Icons.handshake_rounded
                                    : Icons.folder_special_rounded,
                            color: PLDesign.primary,
                          ),
                        ),
                        title: Text(
                          name,
                          style: PLDesign.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${type.label} · $when',
                          style: PLDesign.caption,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new_rounded),
                          onPressed: url.isEmpty ? null : () => _openUrl(url),
                        ),
                        onTap: url.isEmpty ? null : () => _openUrl(url),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
