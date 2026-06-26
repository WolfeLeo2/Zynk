import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyHelper {
  static final _formatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static String format(num amount) {
    if (amount.abs() < 0.01) amount = 0;
    return _formatter.format(amount);
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final rawText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (rawText.isEmpty) return newValue.copyWith(text: '');

    final number = int.parse(rawText);
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: '', // We don't want the KES symbol inside the input value, just commas
      decimalDigits: 0,
    );
    final newString = formatter.format(number).trim();

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
