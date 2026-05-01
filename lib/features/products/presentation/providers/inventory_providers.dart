import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(Supabase.instance.client);
});

/// Key format: "branchId:prod1,prod2,prod3"
final adjustmentStockLevelsProvider = StreamProvider.autoDispose
    .family<Map<String, int>, String>((ref, key) {
  final repo = ref.watch(repositoryProvider);
  
  final parts = key.split(':');
  if (parts.length != 2) return Stream.value({});
  
  final branchId = parts[0];
  final productIds = parts[1].split(',').where((id) => id.isNotEmpty).toList();
  
  if (productIds.isEmpty) return Stream.value({});

  return repo
      .watchStockByProductIds(productIds, branchId: branchId)
      .map((stockList) {
        final result = <String, int>{};
        for (final id in productIds) {
          final stock = stockList.where((s) => s.productId == id).firstOrNull;
          result[id] = stock?.quantity ?? 0;
        }
        return result;
      });
});
