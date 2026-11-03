import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/services/sales_service.dart';

void main() {
  group('SalesService.resolveLine', () {
    test('quantity and price pass through unchanged', () {
      final line = SalesService.resolveLine(
        enteredPrice: 500,
        enteredQty: 3,
      );
      expect(line.quantity, 3);
      expect(line.unitPrice, 500);
      expect(line.total, 1500);
    });

    // The whole point of widening quantity to num: a half unit (a toilet with a
    // broken cistern) must survive to the DB. Rounding here would silently
    // disagree with the stock the sale actually decrements.
    test('a fractional quantity is preserved, not rounded', () {
      final line = SalesService.resolveLine(
        enteredPrice: 100,
        enteredQty: 0.5,
      );
      expect(line.quantity, 0.5);
      expect(line.total, 50);
    });

    test('fractional quantity prices the line proportionally', () {
      final line = SalesService.resolveLine(
        enteredPrice: 750,
        enteredQty: 2.5,
      );
      expect(line.quantity, 2.5);
      expect(line.total, closeTo(1875.0, 0.001));
    });
  });
}
