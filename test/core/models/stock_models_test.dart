import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/models/schema_models.dart';

void main() {
  group('Stock (numeric quantity)', () {
    test('fromMap accepts a whole-number quantity', () {
      final stock = Stock.fromMap({
        'id': 's1',
        'tenant_id': 't1',
        'branch_id': 'b1',
        'product_id': 'p1',
        'quantity': 502,
        'reorder_level': 5,
      });
      expect(stock.quantity, 502);
    });

    test('fromMap accepts a fractional quantity', () {
      final stock = Stock.fromMap({
        'id': 's1',
        'tenant_id': 't1',
        'branch_id': 'b1',
        'product_id': 'p1',
        'quantity': 0.5,
        'reorder_level': 5,
      });
      expect(stock.quantity, 0.5);
    });

    test('toMap round-trips a fractional quantity', () {
      final stock = Stock(
        id: 's1',
        tenantId: 't1',
        branchId: 'b1',
        productId: 'p1',
        quantity: 1.5,
      );
      final map = stock.toMap();
      expect(map['quantity'], 1.5);
      expect(Stock.fromMap(map).quantity, 1.5);
    });
  });

  group('StockAdjustment (numeric quantity)', () {
    test('fromMap accepts a fractional quantity and previous_quantity', () {
      final adj = StockAdjustment.fromMap({
        'id': 'a1',
        'tenant_id': 't1',
        'branch_id': 'b1',
        'product_id': 'p1',
        'quantity': -0.5,
        'previous_quantity': 2.0,
        'status': 'pending',
      });
      expect(adj.quantity, -0.5);
      expect(adj.previousQuantity, 2.0);
    });

    test('toMap round-trips a fractional quantity', () {
      final adj = StockAdjustment(
        id: 'a1',
        tenantId: 't1',
        branchId: 'b1',
        productId: 'p1',
        quantity: 0.5,
      );
      final map = adj.toMap();
      expect(map['quantity'], 0.5);
    });
  });

  group('BatchAdjustmentItem (numeric quantityChange)', () {
    test('accepts both whole and fractional quantity changes', () {
      final whole = BatchAdjustmentItem(productId: 'p1', quantityChange: 5);
      final fractional = BatchAdjustmentItem(
        productId: 'p2',
        quantityChange: -0.5,
      );
      expect(whole.quantityChange, 5);
      expect(fractional.quantityChange, -0.5);
    });
  });
}
