// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Replaces `Text('...')` / `const Text('...')` with `Text(context.l10n.xxx)`.
/// Run from repo root: dart run tool/apply_l10n.dart
void main() {
  final arb = json.decode(File('lib/l10n/app_en.arb').readAsStringSync())
      as Map<String, dynamic>;

  final pairs = <({String getter, String english})>[];
  for (final e in arb.entries) {
    if (e.key.startsWith('@') || e.key == '@@locale') continue;
    if (e.value is! String) continue;
    final english = e.value as String;
    if (english.contains('{')) continue;
    if (english.contains("'") ||
        english.contains('\n') ||
        english.contains(r'$')) {
      continue;
    }
    pairs.add((getter: e.key, english: english));
  }
  pairs.sort((a, b) => b.english.length.compareTo(a.english.length));

  const importLine = "import 'package:parentledger/l10n/context_l10n.dart';\n";

  var total = 0;
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final path = f.path.replaceAll('\\', '/');
    if (path.contains('/l10n/')) continue;
    if (path.contains('/tool/')) continue;

    var content = f.readAsStringSync();
    final original = content;

    for (final p in pairs) {
      final esc = RegExp.escape(p.english);
      final constPat = RegExp("const Text\\(\\s*'$esc'\\)");
      final plainPat = RegExp("(?<!const )Text\\(\\s*'$esc'\\)");

      final c0 = constPat.allMatches(content).length;
      if (c0 > 0) {
        content = content.replaceAll(
          constPat,
          'Text(context.l10n.${p.getter})',
        );
        total += c0;
      }
      final p0 = plainPat.allMatches(content).length;
      if (p0 > 0) {
        content = content.replaceAll(
          plainPat,
          'Text(context.l10n.${p.getter})',
        );
        total += p0;
      }
    }

    if (content != original) {
      if (!content.contains('context_l10n.dart')) {
        final idx = content.indexOf("import 'package:");
        if (idx == -1) {
          content = importLine + content;
        } else {
          final end = content.indexOf('\n', idx);
          content =
              content.substring(0, end + 1) + importLine + content.substring(end + 1);
        }
      }
      f.writeAsStringSync(content);
      print('updated $path');
    }
  }
  print('Total replacements: $total');
}
