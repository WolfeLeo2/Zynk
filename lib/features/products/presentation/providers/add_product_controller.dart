import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:uuid/uuid.dart';

part 'add_product_controller.g.dart';

@Riverpod(keepAlive: true)
class AddProductController extends _$AddProductController {
  @override
  // Keep alive to prevent disposal during async operations like save
  bool updateShouldNotify(AsyncValue<void> previous, AsyncValue<void> next) =>
      previous != next;

  @override
  FutureOr<void> build() {
    // No initial state implementation needed for now
  }

  Future<void> saveProduct({
    String? id, // For update mode
    required List<String> targetBranchIds,
    required String name,
    String? existingImageUrl, // For update mode
    required String? categoryId,
    required String? itemGroupId,
    required String? uomId, // Added

    required double price,
    required double? costPrice, // Added
    double? weight,
    double? length,
    double? width,
    double? height,
    required String sku,
    required String barcode,
    required File? imageFile,
    int? initialStock, // Added for new products
    List<CompositeItemComponent>? components, // Added for composite items
  }) async {
    state = const AsyncLoading();

    try {
      final repository = ref.read(repositoryProvider);
      final profile = ref.read(currentUserProfileProvider).value;
      final tenantId = profile?.tenantId ?? 'tenant_1';
      final normalizedBranchIds = targetBranchIds
          .where((id) => id.isNotEmpty && id != 'all')
          .toSet()
          .toList();
      if (normalizedBranchIds.isEmpty) {
        throw Exception('Please select at least one target branch.');
      }
      final createdBy = profile?.userId ?? 'system';

      String? imageUrl = existingImageUrl;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        final fileExt = imageFile.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final path = 'products/$tenantId/$fileName';

        await Supabase.instance.client.storage
            .from('product-images')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
              ), // Adjust based on ext if needed
            );

        imageUrl = Supabase.instance.client.storage
            .from('product-images')
            .getPublicUrl(path);
      }

      if (id != null) {
        final updatedProduct = Product(
          id: id,
          tenantId: tenantId,
          branchId: null,
          itemGroupId: itemGroupId,
          categoryId: categoryId,
          uomId: uomId, // Added
          name: name,
          sku: sku.isNotEmpty ? sku : null,
          barcode: barcode.isNotEmpty ? barcode : null,
          description: null,
          imageUrl: imageUrl,
          basePrice: price,
          costPrice: costPrice,
          weight: weight,
          length: length,
          width: width,
          height: height,
          taxCategory: 'standard',
          isService: false,
          createdAt: DateTime.now(), // Will be ignored by DB
          updatedAt: DateTime.now(),
        );
        await repository.updateProduct(
          updatedProduct,
          targetBranchIds: normalizedBranchIds,
        );
      } else {
        final newProductId = const Uuid().v4();
        final newProduct = Product(
          id: newProductId,
          tenantId: tenantId,
          branchId: null,
          itemGroupId: itemGroupId,
          categoryId: categoryId,
          uomId: uomId, // Added
          name: name,
          sku: sku.isNotEmpty ? sku : null,
          barcode: barcode.isNotEmpty ? barcode : null,
          description: null,
          imageUrl: imageUrl,
          basePrice: price,
          costPrice: costPrice, // Added
          weight: weight,
          length: length,
          width: width,
          height: height,
          taxCategory: 'standard', // Default
          isService: false, // Default
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (components != null && components.isNotEmpty) {
          await repository.createCompositeProduct(newProduct, components);
        } else {
          await repository.createProduct(
            newProduct,
            targetBranchIds: normalizedBranchIds,
          );
        }

        if (initialStock != null && initialStock > 0) {
          // Initial stock stays branch-scoped even for shared catalog products.
          for (final branchId in normalizedBranchIds) {
            await repository.adjustStock(
              tenantId: tenantId,
              branchId: branchId,
              productId: newProductId,
              adjustmentType: 'initial',
              quantityChange: initialStock,
              createdBy: createdBy,
              notes: 'Initial stock on creation',
            );
          }
        }
      }

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
