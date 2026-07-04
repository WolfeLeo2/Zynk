import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/services/sales_service.dart';

void main() {
  group('SalesService.resolveLine — sqm-based items', () {
    test('rounds sqm quantity UP to the nearest whole box', () {
      // 10 sqm at 1.67 sqm/box needs 6 boxes (5.988 rounded up), not 5.
      final line = SalesService.resolveLine(
        isSqmBased: true,
        coveragePerBox: 1.67,
        enteredPrice: 750,
        enteredQty: 10,
      );
      expect(line.quantity, 6);
      expect(line.unitPrice, closeTo(1252.5, 0.001));
      expect(line.total, closeTo(7515.0, 0.001));
    });

    test('an exact multiple of the coverage needs no extra box', () {
      final line = SalesService.resolveLine(
        isSqmBased: true,
        coveragePerBox: 1.67,
        enteredPrice: 750,
        enteredQty: 3.34, // exactly 2 boxes
      );
      expect(line.quantity, 2);
    });

    test('persists price-per-box, never the raw price-per-sqm', () {
      final line = SalesService.resolveLine(
        isSqmBased: true,
        coveragePerBox: 1.67,
        enteredPrice: 750,
        enteredQty: 1.67,
      );
      expect(line.unitPrice, isNot(750));
      expect(line.unitPrice, closeTo(1252.5, 0.001));
    });

    test('treats a zero or negative coverage as 1.0 (no box conversion)', () {
      final line = SalesService.resolveLine(
        isSqmBased: true,
        coveragePerBox: 0,
        enteredPrice: 100,
        enteredQty: 4.2,
      );
      expect(line.quantity, 5); // ceil(4.2 / 1.0)
      expect(line.unitPrice, 100);
    });
  });

  group('SalesService.resolveLine — non-sqm items', () {
    test('quantity and price pass through unchanged', () {
      final line = SalesService.resolveLine(
        isSqmBased: false,
        coveragePerBox: 1.0,
        enteredPrice: 500,
        enteredQty: 3,
      );
      expect(line.quantity, 3);
      expect(line.unitPrice, 500);
      expect(line.total, 1500);
    });

    test('a fractional quantity is truncated, not rounded', () {
      final line = SalesService.resolveLine(
        isSqmBased: false,
        coveragePerBox: 1.0,
        enteredPrice: 100,
        enteredQty: 5.9,
      );
      expect(line.quantity, 5);
    });
  });
}
