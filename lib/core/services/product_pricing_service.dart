import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schema_models.dart';

final productPricingServiceProvider = Provider(
  (ref) => ProductPricingService(),
);

class ProductPricingService {
  /// Resolves the effective selling price for a product.
  /// Strategy: Product.basePrice > ItemGroup.defaultSellingPrice > 0.0
  double resolveSellingPrice(Product product, ItemGroup? itemGroup) {
    if (product.basePrice != null && product.basePrice! > 0) {
      return product.basePrice!;
    }

    if (itemGroup != null && itemGroup.defaultSellingPrice != null) {
      return itemGroup.defaultSellingPrice!;
    }

    return 0.0;
  }

  /// Resolves the effective buying (cost) price for a product.
  /// Strategy: Product.costPrice > ItemGroup.defaultBuyingPrice > 0.0
  double resolveBuyingPrice(Product product, ItemGroup? itemGroup) {
    if (product.costPrice != null && product.costPrice! > 0) {
      return product.costPrice!;
    }

    if (itemGroup != null && itemGroup.defaultBuyingPrice != null) {
      return itemGroup.defaultBuyingPrice!;
    }

    return 0.0;
  }

  /// Resolves the effective commission configuration.
  /// Returns a record with the type and value.
  ({String type, double value}) resolveCommission(
    Product product,
    ItemGroup? itemGroup,
  ) {
    final type =
        product.commissionType ?? itemGroup?.defaultCommissionType ?? 'none';
    final value =
        product.commissionValue ?? itemGroup?.defaultCommissionValue ?? 0.0;

    return (type: type, value: value);
  }

  /// Resolves the pricing unit for a product.
  /// Strategy: Product.pricingUnit > ItemGroup.defaultPricingUnit > 'piece'
  String resolvePricingUnit(Product product, ItemGroup? itemGroup) {
    return product.pricingUnit ?? itemGroup?.defaultPricingUnit ?? 'piece';
  }

  /// Resolves the coverage per box (square meters per box).
  /// Strategy: Product.coveragePerBox > ItemGroup.defaultCoveragePerBox > 1.0
  double resolveCoveragePerBox(Product product, ItemGroup? itemGroup) {
    final cov = product.coveragePerBox ?? itemGroup?.defaultCoveragePerBox;
    if (cov != null && cov > 0) {
      return cov;
    }
    return 1.0;
  }

  /// Resolves the selling price per box.
  /// If the pricing unit is 'sqm', the box price is calculated as (price_per_sqm * coverage_per_box).
  /// Otherwise, it's just the resolved selling price.
  double resolvePricePerBox(Product product, ItemGroup? itemGroup) {
    final baseSellingPrice = resolveSellingPrice(product, itemGroup);
    final unit = resolvePricingUnit(product, itemGroup);
    if (unit == 'sqm') {
      final coverage = resolveCoveragePerBox(product, itemGroup);
      return baseSellingPrice * coverage;
    }
    return baseSellingPrice;
  }

  /// Resolves the selling price per square meter (if sqm-based).
  /// Otherwise, returns the resolved selling price.
  double resolvePricePerSqm(Product product, ItemGroup? itemGroup) {
    return resolveSellingPrice(product, itemGroup);
  }

  /// Resolves the cost price per box.
  double resolveCostPricePerBox(Product product, ItemGroup? itemGroup) {
    final costPrice = resolveBuyingPrice(product, itemGroup);
    final unit = resolvePricingUnit(product, itemGroup);
    if (unit == 'sqm') {
      final coverage = resolveCoveragePerBox(product, itemGroup);
      return costPrice * coverage;
    }
    return costPrice;
  }
}
