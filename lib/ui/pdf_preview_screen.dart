import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../design/design.dart';

/// Full-screen PDF preview from a local file path (preferred), remote URL, or raw bytes.
///
/// Share opens the system sheet only when the user taps Share — never automatically.
class PDFPreviewScreen extends StatefulWidget {
  const PDFPreviewScreen({
    super.key,
    this.filePath,
    this.downloadUrl,
    this.initialBytes,
    this.title = 'Preview',
  }) : assert(
          filePath != null || downloadUrl != null || initialBytes != null,
          'Provide filePath, downloadUrl, or initialBytes',
        );

  /// Primary: absolute path to a fully written PDF on disk.
  final String? filePath;

  /// Fallback: download then cache to a temp file before display.
  final String? downloadUrl;

  /// Fallback: write to temp file before display (ensures on-disk source for the viewer).
  final Uint8List? initialBytes;

  final String title;

  @override
  State<PDFPreviewScreen> createState() => _PDFPreviewScreenState();
}

class _PDFPreviewScreenState extends State<PDFPreviewScreen> {
  String? _resolvedPath;
  Object? _error;
  bool _resolving = true;
  bool _pdfReady = false;

  @override
  void initState() {
    super.initState();
    _resolveSource();
  }

  Future<void> _resolveSource() async {
    try {
      final existing = widget.filePath;
      if (existing != null && existing.isNotEmpty) {
        final f = File(existing);
        if (await f.exists() && await f.length() > 0) {
          if (!mounted) return;
          setState(() {
            _resolvedPath = f.absolute.path;
            _resolving = false;
          });
          return;
        }
      }

      final bytes = widget.initialBytes;
      if (bytes != null && bytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/court_summary_preview_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        await file.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        setState(() {
          _resolvedPath = file.absolute.path;
          _resolving = false;
        });
        return;
      }

      final url = widget.downloadUrl;
      if (url != null && url.isNotEmpty) {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/court_summary_dl_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        await file.writeAsBytes(res.bodyBytes, flush: true);
        if (!mounted) return;
        setState(() {
          _resolvedPath = file.absolute.path;
          _resolving = false;
        });
        return;
      }

      throw StateError('No PDF source');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _resolving = false;
      });
    }
  }

  Future<void> _share() async {
    final path = _resolvedPath;
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (!await f.exists()) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            path,
            mimeType: 'application/pdf',
            name: 'court_summary.pdf',
          ),
        ],
        subject: widget.title,
      ),
    );
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share',
            onPressed: (_resolvedPath != null && !_resolving) ? _share : null,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: _close,
          ),
        ],
      ),
      body: _resolving
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load PDF.',
                      style: PLDesign.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _resolvedPath == null
                  ? Center(
                      child: Text(
                        'No PDF file.',
                        style: PLDesign.body,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: PDFView(
                            filePath: _resolvedPath,
                            enableSwipe: true,
                            swipeHorizontal: false,
                            autoSpacing: true,
                            pageFling: true,
                            backgroundColor: PLDesign.background,
                            onRender: (_) {
                              if (!mounted) return;
                              setState(() => _pdfReady = true);
                            },
                            onError: (e) {
                              if (!mounted) return;
                              setState(() {
                                _error = e;
                                _pdfReady = false;
                              });
                            },
                            onPageError: (page, e) {
                              if (!mounted) return;
                              setState(() => _error = e);
                            },
                          ),
                        ),
                        if (!_pdfReady)
                          Positioned.fill(
                            child: ColoredBox(
                              color: PLDesign.background,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
