import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';

// Mirrors the live Acme "New ones" product: pricing_unit is set directly on
// the product, but coverage_per_box and the selling price only exist as item
// group defaults ("New Tiles": 750/sqm, 1.67 sqm per box).
Product _sqmProduct({double? coveragePerBox, double? basePrice}) => Product(
  id: 'p1',
  tenantId: 't1',
  name: 'New ones',
  itemGroupId: 'g1',
  pricingUnit: 'sqm',
  basePrice: basePrice,
  coveragePerBox: coveragePerBox,
);

ItemGroup _newTilesGroup() => ItemGroup(
  id: 'g1',
  tenantId: 't1',
  name: 'New Tiles',
  defaultPricingUnit: 'sqm',
  defaultSellingPrice: 750,
  defaultCoveragePerBox: 1.67,
);

void main() {
  group('PosCartItem.isSqmBased', () {
    test('true when the product pricing unit is sqm', () {
      final item = PosCartItem(product: _sqmProduct());
      expect(item.isSqmBased, isTrue);
    });

    test('false for a plain piece-priced product', () {
      final item = PosCartItem(
        product: Product(id: 'p2', tenantId: 't1', name: 'Bag of cement'),
      );
      expect(item.isSqmBased, isFalse);
    });
  });

  group('PosCartItem.coveragePerBox — item group inheritance regression', () {
    // This is the exact bug reported for tenant Acme: create_invoice_screen
    // rebuilt a PosCartItem without passing `itemGroup`, so coveragePerBox
    // silently fell back to 1.0 instead of the group's 1.67, and the
    // per-sqm price (750) got persisted as if it were the per-box price.
    test('resolves from the item group when the product has no coverage of its own', () {
      final item = PosCartItem(
        product: _sqmProduct(),
        itemGroup: _newTilesGroup(),
      );
      expect(item.coveragePerBox, 1.67);
    });

    test('falls back to 1.0 when itemGroup is omitted (the regression)', () {
      final item = PosCartItem(product: _sqmProduct());
      expect(item.coveragePerBox, 1.0);
    });

    test('prefers the product-level coverage over the group default', () {
      final item = PosCartItem(
        product: _sqmProduct(coveragePerBox: 2.0),
        itemGroup: _newTilesGroup(),
      );
      expect(item.coveragePerBox, 2.0);
    });
  });

  group('PosCartItem.pricePerSqm', () {
    test('uses the item group default selling price when the product has none', () {
      final item = PosCartItem(
        product: _sqmProduct(),
        itemGroup: _newTilesGroup(),
      );
      expect(item.pricePerSqm, 750);
    });

    test('overridePrice wins over both product and group price', () {
      final item = PosCartItem(
        product: _sqmProduct(),
        itemGroup: _newTilesGroup(),
        overridePrice: 900,
      );
      expect(item.pricePerSqm, 900);
    });
  });

  group('PosCartItem.effectivePrice — the reported Acme numbers', () {
    test('sqm item with itemGroup charges the correct per-box price (1,252.5)', () {
      final item = PosCartItem(
        product: _sqmProduct(),
        itemGroup: _newTilesGroup(),
        quantity: 1,
      );
      expect(item.effectivePrice, closeTo(1252.5, 0.001));
      expect(item.total, closeTo(1252.5, 0.001));
    });

    test(
      'sqm item WITH an entered price but WITHOUT itemGroup silently '
      'undercharges (750 instead of 1,252.5) — the exact create_invoice_screen '
      'bug: overridePrice carries the entered per-sqm price, but omitting '
      'itemGroup means coveragePerBox never gets applied to it',
      () {
        final item = PosCartItem(
          product: _sqmProduct(),
          overridePrice: 750, // what create_invoice_screen used to pass
          quantity: 1,
        );
        expect(item.effectivePrice, 750);
      },
    );

    test('non-sqm item uses product.basePrice directly', () {
      final item = PosCartItem(
        product: Product(id: 'p2', tenantId: 't1', name: 'Bag of cement', basePrice: 500),
        quantity: 3,
      );
      expect(item.effectivePrice, 500);
      expect(item.total, 1500);
    });
  });

  group('PosCartItem.totalSqm', () {
    test('is quantity (boxes) times coveragePerBox for sqm items', () {
      final item = PosCartItem(
        product: _sqmProduct(),
        itemGroup: _newTilesGroup(),
        quantity: 3,
      );
      expect(item.totalSqm, closeTo(5.01, 0.001));
    });

    test('is zero for non-sqm items', () {
      final item = PosCartItem(
        product: Product(id: 'p2', tenantId: 't1', name: 'Bag of cement'),
        quantity: 3,
      );
      expect(item.totalSqm, 0.0);
    });
  });
}
