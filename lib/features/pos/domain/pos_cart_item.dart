import 'package:zynk/core/models/schema_models.dart';

class PosCartItem {
  final Product product;
  int quantity;

  PosCartItem({required this.product, this.quantity = 1});

  double get total => product.basePrice * quantity;
}
