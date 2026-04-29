import 'package:flutter/services.dart';

/// Formats input as `+1 (XXX) XXX-XXXX` while typing (US numbers only).
class UsPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('1') && digits.length > 1) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final buf = StringBuffer('+1 (');
    for (var i = 0; i < digits.length; i++) {
      if (i == 3) buf.write(') ');
      if (i == 6) buf.write('-');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Returns `+1XXXXXXXXXX` or null if incomplete / invalid length.
String? normalizeUsPhoneToE164(String formatted) {
  var d = formatted.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('1')) {
    d = d.substring(1);
  }
  if (d.length != 10) return null;
  return '+1$d';
}

bool isValidUsPhoneFormatted(String formatted) {
  return normalizeUsPhoneToE164(formatted) != null;
}

/// Formats stored E.164 `+1XXXXXXXXXX` for display in the invite field.
String? e164ToUsDisplay(String? e164) {
  if (e164 == null || e164.isEmpty) return null;
  var d = e164.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('1')) d = d.substring(1);
  if (d.length != 10) return null;
  return '+1 (${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
}
