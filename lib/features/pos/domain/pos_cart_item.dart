import 'package:zynk/core/models/schema_models.dart';

class PosCartItem {
  final Product product;
  int quantity;
  String? overrideName;
  double? overridePrice;

  PosCartItem({
    required this.product, 
    this.quantity = 1,
    this.overrideName,
    this.overridePrice,
  });

  String get effectiveName => overrideName ?? product.name;
  double get effectivePrice => overridePrice ?? product.basePrice;

  double get total => effectivePrice * quantity;
}
