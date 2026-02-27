import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/schema_models.dart';

final csvImportServiceProvider = Provider((ref) => CsvImportService(ref));

class CsvImportService {
  final Ref ref;

  CsvImportService(this.ref);

  Future<List<List<dynamic>>?> pickAndParseCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // required to get bytes on some platforms/web
      );

      if (result != null) {
        final bytes = result.files.single.bytes;
        if (bytes != null) {
          final input = utf8.decode(bytes);
          return csv.decode(input);
        } else if (result.files.single.path != null) {
          final File file = File(result.files.single.path!);
          final input = await file.readAsString();
          return csv.decode(input);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to read CSV file: $e');
    }
  }

  Future<void> importProducts(List<Map<String, dynamic>> parsedProducts) async {
    final repo = ref.read(repositoryProvider);
    final profile = ref.read(currentUserProfileProvider).value;
    final tenantId = profile?.tenantId ?? 'tenant_1';
    final branchId = ref.read(currentBranchIdProvider);
    if (branchId == null)
      throw Exception('No branch selected. Please select a branch first.');
    final createdBy = profile?.userId ?? 'system';

    final categoriesSnapshot = await repo.watchCategories().first;
    final Map<String, String> categoryMap = {
      for (final cat in categoriesSnapshot)
        cat.name.trim().toLowerCase(): cat.id,
    };

    for (final p in parsedProducts) {
      final newProductId = const Uuid().v4();
      final double basePrice =
          double.tryParse(p['selling_price'].toString()) ?? 0.0;
      final double? costPrice = double.tryParse(p['cost_price'].toString());
      final int initialStock = int.tryParse(p['initial_stock'].toString()) ?? 0;

      final String categoryNameRaw =
          p['category']?.toString() ?? 'Uncategorized';
      final String categoryNameClean = categoryNameRaw.trim();
      final String categoryKey = categoryNameClean.toLowerCase();

      String categoryId;
      if (categoryMap.containsKey(categoryKey)) {
        categoryId = categoryMap[categoryKey]!;
      } else {
        categoryId = const Uuid().v4();
        final newCategory = Category(
          id: categoryId,
          tenantId: tenantId,
          name: categoryNameClean,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createCategory(newCategory);
        categoryMap[categoryKey] = categoryId;
      }

      final product = Product(
        id: newProductId,
        tenantId: tenantId,
        itemGroupId:
            null, // CSV batch imports don't link to groups by default yet
        categoryId: categoryId,
        name: p['name'].toString(),
        sku: p['sku']?.toString(),
        barcode: p['barcode']?.toString(),
        description: p['description']?.toString(),
        imageUrl: p['image_url']?.toString(),
        basePrice: basePrice,
        costPrice: costPrice,
        taxCategory: 'standard',
        isService: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.createProduct(product);

      if (initialStock > 0) {
        await repo.adjustStock(
          tenantId: tenantId,
          branchId: branchId,
          productId: newProductId,
          adjustmentType: 'initial',
          quantityChange: initialStock,
          createdBy: createdBy,
          notes: 'Batch CSV import',
        );
      }
    }
  }
}
