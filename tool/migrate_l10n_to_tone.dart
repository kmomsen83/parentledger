// One-shot style migrator: context.l10n.foo -> context.tTone('foo')
// Run from repo root: dart run tool/migrate_l10n_to_tone.dart

import 'dart:io';

void main() async {
  final root = Directory('${Directory.current.path}/lib');
  var files = 0;
  await for (final entity in root.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    var text = await entity.readAsString();
    if (!text.contains('l10n.')) continue;

    final original = text;

    text = text.replaceAll(
      'context.l10n.welcome(',
      'context.tWelcome(',
    );
    text = text.replaceAll(
      'context.l10n.balanceUpdatedMinutesAgo(',
      'context.tBalanceMinutes(',
    );

    text = text.replaceAllMapped(
      RegExp(r'context\.l10n\.([a-zA-Z_][a-zA-Z0-9_]*)(?!\()'),
      (m) => "context.tTone('${m[1]}')",
    );

    if (text != original) {
      await entity.writeAsString(text);
      stdout.writeln(entity.path);
      files++;
    }
  }
  stdout.writeln('Updated $files files.');
}
