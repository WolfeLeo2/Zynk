import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/schema_models.dart';

/// ─────────────────────────────────────────
/// Categories
/// ─────────────────────────────────────────
final allCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchCategories();
});

/// ─────────────────────────────────────────
/// Item Groups
/// ─────────────────────────────────────────
final allItemGroupsProvider = StreamProvider.autoDispose<List<ItemGroup>>((
  ref,
) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchItemGroups();
});

/// ─────────────────────────────────────────
/// Products
/// ─────────────────────────────────────────
final allProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchProducts();
});

/// ─────────────────────────────────────────
/// Stock
/// ─────────────────────────────────────────
final stockProvider = StreamProvider.autoDispose.family<Stock?, String>((
  ref,
  productId,
) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchProductStock(productId);
});

final stockHistoryProvider = StreamProvider.autoDispose
    .family<List<StockAdjustment>, String>((ref, productId) {
      final repository = ref.watch(repositoryProvider);
      return repository.watchProductStockHistory(productId);
    });
