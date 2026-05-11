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
  double get effectivePrice {
    if (overridePrice != null) return overridePrice!;
    if (product.basePrice != null && product.basePrice! > 0) return product.basePrice!;
    return itemGroup?.defaultSellingPrice ?? 0.0;
  }

  double get total => effectivePrice * quantity;
}
