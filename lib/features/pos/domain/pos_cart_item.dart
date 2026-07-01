import 'package:zynk/core/models/schema_models.dart';

class PosCartItem {
  final Product product;
  final ItemGroup? itemGroup;
  int quantity;
  String? overrideName;
  double? overridePrice;

  PosCartItem({
    required this.product,
    this.itemGroup,
    this.quantity = 1,
    this.overrideName,
    this.overridePrice,
  });

  String get effectiveName => overrideName ?? product.name;

  bool get isSqmBased {
    final unit =
        product.pricingUnit ?? itemGroup?.defaultPricingUnit ?? 'piece';
    return unit == 'sqm';
  }

  double get coveragePerBox {
    if (!isSqmBased) return 1.0;
    final cov = product.coveragePerBox ?? itemGroup?.defaultCoveragePerBox;
    if (cov != null && cov > 0) return cov;
    return 1.0;
  }

  double get pricePerSqm {
    if (overridePrice != null) return overridePrice!;
    if (product.basePrice != null && product.basePrice! > 0) {
      return product.basePrice!;
    }
    return itemGroup?.defaultSellingPrice ?? 0.0;
  }

  double get effectivePrice {
    if (isSqmBased) {
      return pricePerSqm * coveragePerBox;
    }
    if (overridePrice != null) return overridePrice!;
    if (product.basePrice != null && product.basePrice! > 0)
      return product.basePrice!;
    return itemGroup?.defaultSellingPrice ?? 0.0;
  }

  double get totalSqm => isSqmBased ? quantity * coveragePerBox : 0.0;

  double get total => effectivePrice * quantity;
}
