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
