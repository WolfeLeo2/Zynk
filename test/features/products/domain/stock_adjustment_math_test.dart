import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/features/products/domain/stock_adjustment_math.dart';

void main() {
  group('resolveStockTarget', () {
    test('add: current + amount', () {
      expect(resolveStockTarget('add', 30, 5), 35);
    });

    test('subtract: current - amount (may go negative for the preview)', () {
      expect(resolveStockTarget('subtract', 3, 5), -2);
    });

    test('set: absolute target, ignores current', () {
      expect(resolveStockTarget('set', 30, 20), 20);
    });

    test('preserves fractional stock', () {
      expect(resolveStockTarget('add', 1.5, 0.5), 2.0);
      expect(resolveStockTarget('set', 10, 0.5), 0.5);
    });

    test('unknown mode is treated as set, never a stray add/subtract', () {
      expect(resolveStockTarget('garbage', 30, 20), 20);
    });
  });

  group('resolveStockDelta — the value persisted as a stock_adjustment', () {
    test('add: delta is +amount, independent of current', () {
      expect(resolveStockDelta('add', 30, 5), 5);
      expect(resolveStockDelta('add', 0, 5), 5);
    });

    test('subtract: delta is -amount, independent of current', () {
      expect(resolveStockDelta('subtract', 30, 5), -5);
    });

    group('set mode — delta depends on the branch current stock', () {
      test('set above current is a positive delta', () {
        // Supabase says 30, sheet says set to 50 → +20.
        expect(resolveStockDelta('set', 30, 50), 20);
      });

      test('set below current is a negative delta (the correction case)', () {
        // Supabase says 30, sheet says set to 20 → -10. This is the exact
        // "stock correction" the Utawala import needed: SET, not ADD.
        expect(resolveStockDelta('set', 30, 20), -10);
      });

      test('set to the same value is a no-op (zero delta, skipped on submit)', () {
        expect(resolveStockDelta('set', 30, 30), 0);
      });

      test('set to zero fully clears the branch', () {
        expect(resolveStockDelta('set', 50, 0), -50);
      });

      test('same target yields a DIFFERENT delta per branch', () {
        // The reason 'set' must resolve per-branch and cannot reuse one delta.
        expect(resolveStockDelta('set', 30, 100), 70);
        expect(resolveStockDelta('set', 80, 100), 20);
      });

      test('fractional set target', () {
        expect(resolveStockDelta('set', 2, 0.5), -1.5);
      });
    });
  });
}
