// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Ensures every `context.l10n.foo` used in lib/ has an ARB entry (English + Spanish).
void main() {
  final used = <String>{};
  final pat = RegExp(r'context\.l10n\.(\w+)');
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('l10n${Platform.pathSeparator}')) continue;
    final t = f.readAsStringSync();
    for (final m in pat.allMatches(t)) {
      used.add(m.group(1)!);
    }
  }

  final enPath = File('lib/l10n/app_en.arb');
  final esPath = File('lib/l10n/app_es.arb');
  final en = json.decode(enPath.readAsStringSync()) as Map<String, dynamic>;
  final es = json.decode(esPath.readAsStringSync()) as Map<String, dynamic>;

  var added = 0;
  for (final key in used) {
    if (key == 'welcome' || en.containsKey('@$key')) continue;
    if (en.containsKey(key) && en[key] is String) continue;
    if (en[key] is Map) continue;
    final guess = guessEnglish(key);
    en[key] = guess;
    es[key] = guess;
    added++;
  }

  // Preserve @welcome metadata
  if (en['welcome'] == 'Welcome back, {name}' && !en.containsKey('@welcome')) {
    en['@welcome'] = {
      'placeholders': {'name': {'type': 'String'}},
    };
  }

  enPath.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(en));
  esPath.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(es));
  print('Added $added missing keys (${used.length} referenced).');
}

String guessEnglish(String camel) {
  final buf = StringBuffer();
  for (var i = 0; i < camel.length; i++) {
    final c = camel[i];
    if (i > 0 && c.toUpperCase() == c && c.toLowerCase() != c) {
      buf.write(' ');
    }
    buf.write(c);
  }
  final words = buf.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final parts = words.map((w) {
    if (w.length == 1) return w.toUpperCase();
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
  return parts.isEmpty ? camel : parts;
}
