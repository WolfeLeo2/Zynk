import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(Supabase.instance.client);
});

/// Key format: comma-joined product ids ("prod1,prod2,prod3").
/// Returns current stock for every branch keyed by "branchId:productId", so a
/// single adjustment bundle that fanned out across branches can look up each
/// row's own branch stock (not just the first branch's).
final adjustmentStockLevelsProvider = StreamProvider.autoDispose
    .family<Map<String, num>, String>((ref, key) {
      final repo = ref.watch(repositoryProvider);

      final productIds = key.split(',').where((id) => id.isNotEmpty).toList();
      if (productIds.isEmpty) return Stream.value({});

      return repo.watchStockByProductIds(productIds).map((stockList) {
        final result = <String, num>{};
        for (final s in stockList) {
          result['${s.branchId}:${s.productId}'] = s.quantity;
        }
        return result;
      });
    });
