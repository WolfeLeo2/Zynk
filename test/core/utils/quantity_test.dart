import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/utils/quantity.dart';

void main() {
  group('formatQty — display rendering of numeric stock', () {
    test('whole numbers render without a trailing .0', () {
      expect(formatQty(502), '502');
      expect(formatQty(0), '0');
      expect(formatQty(120.0), '120'); // a double that is whole
    });

    test('fractional values render with up to 2 decimals', () {
      expect(formatQty(0.5), '0.5');
      expect(formatQty(1.5), '1.5');
      expect(formatQty(1.25), '1.25');
    });

    test('rounds to 2 decimals', () {
      expect(formatQty(1.666), '1.67');
    });

    test('adds thousands separators', () {
      expect(formatQty(1250), '1,250');
      expect(formatQty(1252.5), '1,252.5'); // sqm per-box (750 x 1.67)
    });

    test('handles negatives (a subtract/correction delta)', () {
      expect(formatQty(-0.5), '-0.5');
      expect(formatQty(-10), '-10');
    });
  });

  group('formatQtyInput — same rounding, no thousands separators', () {
    test('no grouping so it can prefill a text field', () {
      expect(formatQtyInput(1250), '1250');
      expect(formatQtyInput(0.5), '0.5');
      expect(formatQtyInput(120.0), '120');
    });
  });
}
