import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/adjustment_reason.dart';
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
  final branchId = ref.watch(currentBranchIdProvider);
  return repository.watchProducts(branchId: branchId);
});

/// ─────────────────────────────────────────
/// Stock
/// ─────────────────────────────────────────
final stockProvider = StreamProvider.autoDispose.family<Stock?, String>((
  ref,
  productId,
) {
  final repository = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repository.watchProductStock(productId, branchId: branchId);
});

final stockHistoryProvider = StreamProvider.autoDispose
    .family<List<StockAdjustment>, String>((ref, productId) {
      final repository = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      return repository.watchProductStockHistory(productId, branchId: branchId);
    });

/// ─────────────────────────────────────────
/// Adjustment Reasons
/// ─────────────────────────────────────────
final adjustmentReasonsProvider =
    StreamProvider.autoDispose<List<AdjustmentReason>>((ref) {
      final repository = ref.watch(repositoryProvider);
      final tenantId = ref.watch(tenantIdProvider) ?? '';
      return repository.watchAdjustmentReasons(tenantId);
    });

/// ─────────────────────────────────────────
/// Units of Measurement
/// ─────────────────────────────────────────
final allUomProvider = StreamProvider.autoDispose<List<UnitOfMeasurement>>((
  ref,
) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchUnitOfMeasurements();
});

/// ─────────────────────────────────────────
/// Composite Components
/// ─────────────────────────────────────────
final compositeComponentsProvider = StreamProvider.autoDispose
    .family<List<CompositeItemComponent>, String>((ref, parentId) {
      final repository = ref.watch(repositoryProvider);
      return repository.watchCompositeComponents(parentId);
    });

/// ─────────────────────────────────────────
/// Composite Products (filtered)
/// ─────────────────────────────────────────
final compositeProductsProvider = StreamProvider.autoDispose<List<Product>>((
  ref,
) {
  final repository = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  // All products stream (composite filter removed temporarily)
  return repository
      .watchProducts(branchId: branchId)
      .map((products) => products.toList());
});
