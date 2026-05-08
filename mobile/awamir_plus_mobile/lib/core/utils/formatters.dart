import 'package:flutter/material.dart';

const _localizedDigitMap = {
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
  '۰': '0',
  '۱': '1',
  '۲': '2',
  '۳': '3',
  '۴': '4',
  '۵': '5',
  '۶': '6',
  '۷': '7',
  '۸': '8',
  '۹': '9',
};

String normalizeLocalizedDigits(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_localizedDigitMap[char] ?? char);
  }
  return buffer.toString();
}

String normalizePhoneInput(String value) {
  return normalizeLocalizedDigits(value)
      .replaceAll(RegExp(r'[\s\-\(\)\u200e\u200f]'), '')
      .trim();
}

String formatCurrency(num value, {bool symbol = true}) {
  final rounded = value.round().toString();
  final formatted = rounded.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return symbol ? '$formatted ر.س' : formatted;
}

String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
