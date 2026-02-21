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
    required String name,
    String? existingImageUrl, // For update mode
    required String? categoryId,
    required String? itemGroupId,
    required double price,
    required double? costPrice, // Added
    required String sku,
    required String barcode,
    required String commissionType,
    required double commissionValue,
    required File? imageFile,
  }) async {
    state = const AsyncLoading();

    try {
      final repository = ref.read(repositoryProvider);
      final profile = ref.read(currentUserProfileProvider).value;
      final tenantId = profile?.tenantId ?? 'tenant_1';

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
          itemGroupId: itemGroupId,
          categoryId: categoryId,
          name: name,
          sku: sku.isNotEmpty ? sku : null,
          barcode: barcode.isNotEmpty ? barcode : null,
          description: null,
          imageUrl: imageUrl,
          basePrice: price,
          costPrice: costPrice,
          taxCategory: 'standard',
          isService: false,
          commissionType: commissionType,
          commissionValue: commissionValue,
          createdAt: DateTime.now(), // Will be ignored by DB
          updatedAt: DateTime.now(),
        );
        await repository.updateProduct(updatedProduct);
      } else {
        final newProduct = Product(
          id: const Uuid().v4(),
          tenantId: tenantId,
          itemGroupId: itemGroupId,
          categoryId: categoryId,
          name: name,
          sku: sku.isNotEmpty ? sku : null,
          barcode: barcode.isNotEmpty ? barcode : null,
          description: null, // TODO: Add description field to form
          imageUrl: imageUrl,
          basePrice: price,
          costPrice: costPrice, // Added
          taxCategory: 'standard', // Default
          isService: false, // Default
          commissionType: commissionType,
          commissionValue: commissionValue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.createProduct(newProduct);
      }

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
