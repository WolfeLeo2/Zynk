import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/services/product_pricing_service.dart';

Product _product({
  double? basePrice,
  double? costPrice,
  String? pricingUnit,
  double? coveragePerBox,
  String? commissionType,
  double? commissionValue,
}) => Product(
  id: 'p1',
  tenantId: 't1',
  name: 'Test product',
  basePrice: basePrice,
  costPrice: costPrice,
  pricingUnit: pricingUnit,
  coveragePerBox: coveragePerBox,
  commissionType: commissionType,
  commissionValue: commissionValue,
);

ItemGroup _group({
  double? defaultSellingPrice,
  double? defaultBuyingPrice,
  String? defaultPricingUnit,
  double? defaultCoveragePerBox,
  String? defaultCommissionType,
  double? defaultCommissionValue,
}) => ItemGroup(
  id: 'g1',
  tenantId: 't1',
  name: 'Test group',
  defaultSellingPrice: defaultSellingPrice,
  defaultBuyingPrice: defaultBuyingPrice,
  defaultPricingUnit: defaultPricingUnit,
  defaultCoveragePerBox: defaultCoveragePerBox,
  defaultCommissionType: defaultCommissionType,
  defaultCommissionValue: defaultCommissionValue,
);

void main() {
  final service = ProductPricingService();

  group('resolveSellingPrice', () {
    test('prefers product.basePrice when set and positive', () {
      final product = _product(basePrice: 100);
      final group = _group(defaultSellingPrice: 999);
      expect(service.resolveSellingPrice(product, group), 100);
    });

    test('falls back to item group default when product price is null', () {
      final product = _product();
      final group = _group(defaultSellingPrice: 750);
      expect(service.resolveSellingPrice(product, group), 750);
    });

    test('falls back to item group default when product price is zero', () {
      final product = _product(basePrice: 0);
      final group = _group(defaultSellingPrice: 750);
      expect(service.resolveSellingPrice(product, group), 750);
    });

    test('returns 0.0 when neither product nor group has a price', () {
      final product = _product();
      expect(service.resolveSellingPrice(product, null), 0.0);
    });
  });

  group('resolvePricingUnit', () {
    test('prefers the product-level pricing unit', () {
      final product = _product(pricingUnit: 'sqm');
      final group = _group(defaultPricingUnit: 'piece');
      expect(service.resolvePricingUnit(product, group), 'sqm');
    });

    test('falls back to the item group default pricing unit', () {
      final product = _product();
      final group = _group(defaultPricingUnit: 'sqm');
      expect(service.resolvePricingUnit(product, group), 'sqm');
    });

    test('defaults to piece when nothing is set', () {
      final product = _product();
      expect(service.resolvePricingUnit(product, null), 'piece');
    });
  });

  group('resolveCoveragePerBox — the "New ones" regression', () {
    // Reproduces the live Acme "New ones" product: pricing_unit set directly
    // on the product, but coverage_per_box only set on the item group.
    test('inherits coverage_per_box from the item group when product has none', () {
      final product = _product(pricingUnit: 'sqm');
      final group = _group(defaultPricingUnit: 'sqm', defaultCoveragePerBox: 1.67);
      expect(service.resolveCoveragePerBox(product, group), 1.67);
    });

    test('prefers the product-level coverage over the group default', () {
      final product = _product(pricingUnit: 'sqm', coveragePerBox: 2.0);
      final group = _group(defaultCoveragePerBox: 1.67);
      expect(service.resolveCoveragePerBox(product, group), 2.0);
    });

    test('falls back to 1.0 when there is no item group at all', () {
      final product = _product(pricingUnit: 'sqm');
      expect(service.resolveCoveragePerBox(product, null), 1.0);
    });

    test(
      'a zero coverage on the product falls through to the 1.0 default, '
      'NOT the group default (?? only checks for null, not falsy)',
      () {
        final product = _product(pricingUnit: 'sqm', coveragePerBox: 0);
        final group = _group(defaultCoveragePerBox: 1.67);
        expect(service.resolveCoveragePerBox(product, group), 1.0);
      },
    );
  });

  group('resolvePricePerBox / resolvePricePerSqm', () {
    test('sqm products multiply price/sqm by coverage to get price/box', () {
      final product = _product(pricingUnit: 'sqm');
      final group = _group(defaultSellingPrice: 750, defaultCoveragePerBox: 1.67);
      expect(service.resolvePricePerSqm(product, group), 750);
      expect(service.resolvePricePerBox(product, group), closeTo(1252.5, 0.001));
    });

    test('non-sqm products have the same price per box and per unit', () {
      final product = _product(basePrice: 200);
      expect(service.resolvePricePerBox(product, null), 200);
    });
  });

  group('resolveCostPricePerBox', () {
    test('sqm products multiply cost/sqm by coverage', () {
      final product = _product(pricingUnit: 'sqm', costPrice: 600);
      final group = _group(defaultCoveragePerBox: 1.67);
      expect(service.resolveCostPricePerBox(product, group), closeTo(1002.0, 0.001));
    });
  });

  group('resolveCommission', () {
    test('prefers product-level commission config', () {
      final product = _product(commissionType: 'flat', commissionValue: 50);
      final group = _group(defaultCommissionType: 'percentage', defaultCommissionValue: 10);
      final commission = service.resolveCommission(product, group);
      expect(commission.type, 'flat');
      expect(commission.value, 50);
    });

    test('falls back to item group default commission', () {
      final product = _product();
      final group = _group(defaultCommissionType: 'percentage', defaultCommissionValue: 10);
      final commission = service.resolveCommission(product, group);
      expect(commission.type, 'percentage');
      expect(commission.value, 10);
    });

    test('defaults to none/0 when nothing is configured', () {
      final product = _product();
      final commission = service.resolveCommission(product, null);
      expect(commission.type, 'none');
      expect(commission.value, 0.0);
    });
  });
}
