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

final itemGroupProvider = StreamProvider.autoDispose.family<ItemGroup?, String>((ref, id) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchItemGroup(id);
});

/// ─────────────────────────────────────────
/// Products
/// ─────────────────────────────────────────
/// ─────────────────────────────────────────
/// Products
/// ─────────────────────────────────────────
final productsByBranchProvider =
    StreamProvider.autoDispose.family<List<Product>, String?>((ref, branchId) {
      final repository = ref.watch(repositoryProvider);
      return repository.watchProducts(branchId: branchId);
    });

final allProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final repository = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repository.watchProducts(branchId: branchId);
});

final productsByGroupProvider =
    StreamProvider.autoDispose.family<List<Product>, String>((ref, groupId) {
      final repository = ref.watch(repositoryProvider);
      return repository.watchProductsByGroup(groupId);
    });

/// ─────────────────────────────────────────
/// Stock
/// ─────────────────────────────────────────
typedef StockArg = ({String productId, String? branchId});

final stockByBranchProvider = StreamProvider.autoDispose
    .family<Stock?, StockArg>((ref, arg) {
      final repository = ref.watch(repositoryProvider);
      return repository.watchProductStock(arg.productId, branchId: arg.branchId);
    });

final stockProvider = StreamProvider.autoDispose.family<Stock?, String>((
  ref,
  productId,
) {
  final repository = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repository.watchProductStock(productId, branchId: branchId);
});

final branchStocksProvider = StreamProvider.autoDispose
    .family<List<Stock>, String>((ref, productId) {
      final repository = ref.watch(repositoryProvider);
      return repository.watchProductBranchStocks(productId);
    });

final stockHistoryByBranchProvider = StreamProvider.autoDispose
    .family<List<StockAdjustment>, StockArg>((ref, arg) {
      final repository = ref.watch(repositoryProvider);
      return repository.watchProductStockHistory(
        arg.productId,
        branchId: arg.branchId,
      );
    });

final stockHistoryProvider = StreamProvider.autoDispose
    .family<List<StockAdjustment>, String>((ref, productId) {
      final repository = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      return repository.watchProductStockHistory(productId, branchId: branchId);
    });

final productTransactionHistoryProvider = StreamProvider.autoDispose
    .family<List<ProductTransaction>, String>((ref, productId) {
      final repository = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      return repository.watchProductTransactionHistory(productId, branchId: branchId);
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
final compositeProductsByBranchProvider =
    StreamProvider.autoDispose.family<List<Product>, String?>((ref, branchId) {
      final repository = ref.watch(repositoryProvider);
      return repository
          .watchProducts(branchId: branchId)
          .map((products) => products.toList());
    });

final compositeProductsProvider = StreamProvider.autoDispose<List<Product>>((
  ref,
) {
  final repository = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repository
      .watchProducts(branchId: branchId)
      .map((products) => products.toList());
});

final productCountByGroupProvider =
    Provider.autoDispose.family<int, String>((ref, groupId) {
      final products = ref.watch(allProductsProvider).value ?? [];
      return products.where((p) => p.itemGroupId == groupId).length;
    });
