import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/case_document_category.dart';
import '../providers/case_context.dart';
import '../services/case_document_service.dart';
import '../services/counsel_access_policy.dart';
import 'widgets/premium_upgrade_sheet.dart';

/// Shared case document library with attorney upload support.
///
/// Pass [caseId] when opening from the attorney portal so the correct matter is used.
class DocumentsLibraryScreen extends StatefulWidget {
  const DocumentsLibraryScreen({
    super.key,
    this.caseId,
    this.embedInParent = false,
  });

  /// When set (e.g. attorney dashboard), overrides [CaseContext.caseId].
  final String? caseId;

  /// Nested under counsel [ClientCaseScreen] tabs (toolbar row instead of app bar).
  final bool embedInParent;

  @override
  State<DocumentsLibraryScreen> createState() => _DocumentsLibraryScreenState();
}

class _DocumentsLibraryScreenState extends State<DocumentsLibraryScreen> {
  bool _uploading = false;
  Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _gateFreeTierParent());
  }

  Future<void> _gateFreeTierParent() async {
    if (!mounted) return;
    final s = context.read<CaseContext>();
    if (s.isAttorney || s.unlockedParentPremiumFeatures) return;
    await showPremiumUpgradeSheet(
      context,
      feature: DashboardPremiumFeature.documentsLibrary,
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  String? _effectiveCaseId(BuildContext context) {
    final v = widget.caseId?.trim();
    if (v != null && v.isNotEmpty) return v;
    return context.watch<CaseContext>().caseId;
  }

  Future<void> _ensureNameCache(Iterable<String> uids) async {
    final missing = uids.where((u) => !_nameCache.containsKey(u)).toSet();
    if (missing.isEmpty) return;
    final next = await CaseDocumentService.loadUploaderNames(missing);
    if (mounted) setState(() => _nameCache = {..._nameCache, ...next});
  }

  Future<void> _uploadFlow(BuildContext context, String caseId) async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    try {
      final categoryHolder = <CaseDocumentCategory>[CaseDocumentCategory.evidence];

      final metaOk = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: PLDesign.surface,
            title: Text('Upload document', style: PLDesign.sectionTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<CaseDocumentCategory>(
                    key: ValueKey<CaseDocumentCategory>(categoryHolder[0]),
                    initialValue: categoryHolder[0],
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: PLDesign.border),
                      ),
                    ),
                    dropdownColor: PLDesign.card,
                    items: CaseDocumentCategory.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => categoryHolder[0] = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Temporary custody order — Aug 2026',
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: PLDesign.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PLDesign.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      alignLabelWithHint: true,
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: PLDesign.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PLDesign.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Choose file')),
            ],
          ),
        ),
      );
      if (metaOk != true || !context.mounted) return;

      final title = titleCtrl.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a title for this document.')),
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
      );
      if (!context.mounted) return;
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      final path = f.path;
      if (path == null) return;
      final name = f.name;

      final session = context.read<CaseContext>();
      if (session.isAttorney) {
        final nBytes = f.size > 0 ? f.size : await File(path).length();
        if (CounselAccessPolicy.fileExceedsAttorneyLimit(nBytes)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('That file is too large to upload.')),
            );
          }
          return;
        }
      }

      setState(() => _uploading = true);
      try {
        await CaseDocumentService.uploadDocument(
          caseId: caseId,
          file: File(path),
          fileName: name,
          category: categoryHolder[0],
          title: title,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tTone('documentUploaded'))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is CounselUploadLimitException
                    ? 'That file is too large to upload.'
                    : 'Upload failed: $e',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } finally {
      titleCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  String _categoryLabel(Map<String, dynamic> d) {
    final raw = d['category'] ?? d['type'];
    return CaseDocumentCategory.fromFirestore(raw).label;
  }

  bool _isCourtOrder(Map<String, dynamic> d) =>
      CaseDocumentCategory.fromFirestore(d['category'] ?? d['type']).isCourtOrder;

  String _displayTitle(Map<String, dynamic> d) {
    final t = (d['title'] ?? '').toString().trim();
    if (t.isNotEmpty) return t;
    return (d['fileName'] ?? 'Document').toString();
  }

  String _uploaderLabel(String uid, Map<String, dynamic>? userRoleHint) {
    final name = _nameCache[uid] ?? '…';
    final role = (userRoleHint?['uploaderRole'] ?? '').toString();
    final isAttorney = role == 'attorney';
    final short =
        role.isEmpty ? '' : (isAttorney ? 'Attorney' : 'Parent');
    if (short.isEmpty) return name;
    return '$name · $short';
  }

  Future<void> _maybeSupersedeOrRemove(
    BuildContext context, {
    required String caseId,
    required String docId,
    required Map<String, dynamic> data,
    required bool isOwner,
  }) async {
    if (!isOwner) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PLDesign.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded),
              title: const Text('Mark as superseded'),
              subtitle: const Text('Keeps the file for audit; flag as replaced'),
              onTap: () => Navigator.pop(ctx, 'supersede'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: PLDesign.danger),
              title: Text('Remove from library', style: TextStyle(color: PLDesign.danger)),
              subtitle: const Text('Soft-delete for your account; record retained'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    try {
      if (action == 'supersede') {
        await CaseDocumentService.markSuperseded(caseId: caseId, documentId: docId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as superseded.')),
          );
        }
      } else {
        await CaseDocumentService.markDeleted(caseId: caseId, documentId: docId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document removed from library.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseId = _effectiveCaseId(context);
    final df = DateFormat.yMMMd().add_jm();
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final appBar = widget.embedInParent
        ? null
        : AppBar(
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
                  onPressed:
                      caseId == null ? null : () => _uploadFlow(context, caseId),
                ),
            ],
          );

    Widget bodyCore = caseId == null
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
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rawDocs = snap.data?.docs ?? [];
                final docs = rawDocs.where((doc) {
                  final del = doc.data()['deleted'];
                  return del != true;
                }).toList();

                final uploaderIds = docs.map((e) => (e.data()['uploadedBy'] ?? '').toString()).where((s) => s.isNotEmpty);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ensureNameCache(uploaderIds);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 56, color: PLDesign.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'No documents yet',
                            style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload court orders, filings, agreements, or evidence. '
                            'Documents are locked after upload — only lifecycle flags can change.',
                            style: PLDesign.caption.copyWith(height: 1.35),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _uploadFlow(context, caseId),
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
                    final id = doc.id;
                    final url = (d['fileUrl'] ?? '').toString();
                    final uploadedBy = (d['uploadedBy'] ?? '').toString();
                    final uploaded = d['uploadedAt'] ?? d['createdAt'];
                    String when = '—';
                    if (uploaded is Timestamp) {
                      when = df.format(uploaded.toDate());
                    }
                    final court = _isCourtOrder(d);
                    final superseded = d['superseded'] == true;
                    final notes = (d['notes'] ?? '').toString().trim();
                    final isOwner = uploadedBy.isNotEmpty && uploadedBy == myUid;

                    final borderColor = court
                        ? const Color(0xfff59e0b)
                        : PLDesign.border;

                    return Material(
                      color: PLDesign.card,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: superseded ? PLDesign.textMuted : borderColor,
                            width: court ? 1.6 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: court
                                        ? const Color(0xfff59e0b).withValues(alpha: 0.2)
                                        : PLDesign.primary.withValues(alpha: 0.15),
                                    child: Icon(
                                      court ? Icons.account_balance_rounded : Icons.description_rounded,
                                      color: court ? const Color(0xfff59e0b) : PLDesign.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _displayTitle(d),
                                          style: PLDesign.body.copyWith(
                                            fontWeight: FontWeight.w700,
                                            decoration: superseded
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: PLDesign.surface,
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(color: PLDesign.border),
                                              ),
                                              child: Text(
                                                _categoryLabel(d),
                                                style: PLDesign.caption.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (court)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xfff59e0b).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  'Court-related',
                                                  style: PLDesign.caption.copyWith(
                                                    color: const Color(0xfff59e0b),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            if (superseded)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: PLDesign.textMuted.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  'Superseded',
                                                  style: PLDesign.caption.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Uploaded by ${_uploaderLabel(uploadedBy, d)}',
                                          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                                        ),
                                        Text(
                                          when,
                                          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                                        ),
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            notes,
                                            style: PLDesign.caption.copyWith(height: 1.35),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    IconButton(
                                      tooltip: 'Lifecycle',
                                      icon: const Icon(Icons.more_vert_rounded),
                                      onPressed: superseded
                                          ? null
                                          : () => _maybeSupersedeOrRemove(
                                                context,
                                                caseId: caseId,
                                                docId: id,
                                                data: d,
                                                isOwner: isOwner,
                                              ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: url.isEmpty ? null : () => _openUrl(url),
                                      icon: const Icon(Icons.visibility_rounded, size: 18),
                                      label: const Text('View'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: url.isEmpty ? null : () => _openUrl(url),
                                      icon: const Icon(Icons.download_rounded, size: 18),
                                      label: const Text('Download'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: PLDesign.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );

    final body = widget.embedInParent && caseId != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: PLDesign.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tTone('caseDocuments'),
                          style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                        ),
                      ),
                      if (_uploading)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          tooltip: 'Upload',
                          icon: const Icon(Icons.cloud_upload_outlined),
                          onPressed: () => _uploadFlow(context, caseId),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: bodyCore),
            ],
          )
        : bodyCore;

    return Scaffold(
      primary: !widget.embedInParent,
      backgroundColor: PLDesign.background,
      appBar: appBar,
      body: body,
    );
  }
}
