/// Light-touch formatting for legally recorded messages: trim, sentence case,
/// and optional normalization of accidental ALL-CAPS blocks (does not rewrite intent).
class MessageTextFormatter {
  MessageTextFormatter._();

  /// Trims, fixes sentence capitalization, and optionally softens shouting.
  static String formatProfessionalMessage(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    if (_accidentalAllCaps(s)) {
      s = s.toLowerCase();
    }

    return _capitalizeSentenceStarts(s);
  }

  /// True when the user likely has caps-lock on: long single word or multi-word shout.
  static bool _accidentalAllCaps(String s) {
    final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length < 2) return false;
    if (letters != letters.toUpperCase()) return false;
    // Short acronyms / single short tokens: leave as-is (e.g. "OK", "USA").
    if (!RegExp(r'\s').hasMatch(s) && letters.length <= 5) {
      return false;
    }
    if (RegExp(r'\s').hasMatch(s)) return true;
    return letters.length > 12;
  }

  /// Capitalizes the first letter and letters after `.` `!` `?` (after optional spaces).
  static String _capitalizeSentenceStarts(String s) {
    final out = StringBuffer();
    var needCapitalize = true;
    var i = 0;

    while (i < s.length) {
      final unit = s[i];
      if (needCapitalize && _isAsciiLetter(unit)) {
        out.write(unit.toUpperCase());
        needCapitalize = false;
        i++;
        continue;
      }
      if (needCapitalize) {
        out.write(unit);
        i++;
        continue;
      }

      out.write(unit);
      if (unit == '.' || unit == '!' || unit == '?') {
        i++;
        while (i < s.length &&
            (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) {
          out.write(s[i]);
          i++;
        }
        needCapitalize = true;
      } else {
        i++;
      }
    }

    return out.toString();
  }

  static bool _isAsciiLetter(String c) =>
      c.length == 1 &&
      ((c.codeUnitAt(0) >= 0x41 && c.codeUnitAt(0) <= 0x5a) ||
          (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7a));
}
