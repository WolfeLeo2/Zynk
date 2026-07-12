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

  // Base per-unit price before any override. Item-group pricing is
  // authoritative; product base price is the fallback. For sqm items this is
  // the per-BOX price (per-sqm price × coverage); otherwise per piece.
  double get _baseUnitPrice {
    final groupPrice = itemGroup?.defaultSellingPrice;
    final base = (groupPrice != null && groupPrice > 0)
        ? groupPrice
        : (product.basePrice != null && product.basePrice! > 0
              ? product.basePrice!
              : 0.0);
    return isSqmBased ? base * coveragePerBox : base;
  }

  /// Effective unit price charged: per box for sqm items, per piece otherwise.
  /// A manual per-line [overridePrice] (also per box / per piece) wins.
  double get effectivePrice => overridePrice ?? _baseUnitPrice;

  /// Per-sqm equivalent — secondary display only.
  double get pricePerSqm => isSqmBased && coveragePerBox > 0
      ? effectivePrice / coveragePerBox
      : effectivePrice;

  double get totalSqm => isSqmBased ? quantity * coveragePerBox : 0.0;

  double get total => effectivePrice * quantity;
}
