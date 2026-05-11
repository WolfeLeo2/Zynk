import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schema_models.dart';

final productPricingServiceProvider = Provider((ref) => ProductPricingService());

class ProductPricingService {
  /// Resolves the effective selling price for a product.
  /// Strategy: Product.basePrice > ItemGroup.defaultSellingPrice > 0.0
  double resolveSellingPrice(
    Product product,
    ItemGroup? itemGroup,
  ) {
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
  double resolveBuyingPrice(
    Product product,
    ItemGroup? itemGroup,
  ) {
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
    final type = product.commissionType ?? itemGroup?.defaultCommissionType ?? 'none';
    final value = product.commissionValue ?? itemGroup?.defaultCommissionValue ?? 0.0;
    
    return (type: type, value: value);
  }
}
