import 'package:intl/intl.dart';

/// Formats a stock/adjustment quantity for display: whole numbers show with no
/// decimal ("502"), fractional ones show up to 2 decimal places ("0.5").
final _qtyFormat = NumberFormat('#,##0.##');
String formatQty(num quantity) => _qtyFormat.format(quantity);

/// Same rounding as [formatQty] but without thousands separators — for
/// prefilling an editable text field.
final _qtyInputFormat = NumberFormat('0.##');
String formatQtyInput(num quantity) => _qtyInputFormat.format(quantity);
