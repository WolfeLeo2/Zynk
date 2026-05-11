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
    final selectedBranchId = ref.read(currentBranchIdProvider);
    if (selectedBranchId == null) {
      throw Exception('No branch selected. Please select a branch first.');
    }
    final allBranchesMode = selectedBranchId == 'all';
    final targetBranches = allBranchesMode
        ? (await repo.getBranches(
            tenantId,
          )).where((b) => b.id != 'all').toList()
        : const <Branch>[];
    final targetBranchIds = allBranchesMode
        ? targetBranches.map((b) => b.id).toList()
        : <String>[selectedBranchId];

    if (allBranchesMode && targetBranches.isEmpty) {
      throw Exception(
        'All Branches selected but no target branches were found for this tenant.',
      );
    }
    final createdBy = profile?.userId ?? 'system';
    final bundleId = const Uuid().v4();

    final categoriesSnapshot = await repo.watchCategories().first;
    final Map<String, String> categoryMap = {
      for (final cat in categoriesSnapshot)
        cat.name.trim().toLowerCase(): cat.id,
    };

    final groupsSnapshot = await repo.watchItemGroups().first;
    final Map<String, String> groupMap = {
      for (final group in groupsSnapshot)
        group.name.trim().toLowerCase(): group.id,
    };

    for (final p in parsedProducts) {
      final newProductId = const Uuid().v4();
      
      // Pricing
      final sellingPriceRaw = p['selling_price']?.toString() ?? '';
      final double? basePrice = sellingPriceRaw.isEmpty ? null : double.tryParse(sellingPriceRaw);
      
      final costPriceRaw = p['cost_price']?.toString() ?? '';
      final double? costPrice = costPriceRaw.isEmpty ? null : double.tryParse(costPriceRaw);
      
      final int initialStock = int.tryParse(p['initial_stock'].toString()) ?? 0;

      // Category Resolution
      final String categoryNameRaw = p['category']?.toString() ?? 'Uncategorized';
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
          branchId: allBranchesMode ? null : selectedBranchId,
          name: categoryNameClean,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createCategory(newCategory);
        categoryMap[categoryKey] = categoryId;
      }

      // Item Group Resolution
      final String groupNameRaw = p['item_group']?.toString() ?? 'Default';
      final String groupNameClean = groupNameRaw.trim();
      final String groupKey = groupNameClean.toLowerCase();

      String? itemGroupId;
      if (groupMap.containsKey(groupKey)) {
        itemGroupId = groupMap[groupKey]!;
      } else {
        itemGroupId = const Uuid().v4();
        
        // Parse optional group defaults from CSV row if present
        final defSelling = double.tryParse(p['group_selling_price']?.toString() ?? '');
        final defBuying = double.tryParse(p['group_buying_price']?.toString() ?? '');
        final commType = p['group_commission_type']?.toString();
        final commValue = double.tryParse(p['group_commission_value']?.toString() ?? '');

        final newGroup = ItemGroup(
          id: itemGroupId,
          tenantId: tenantId,
          branchId: allBranchesMode ? null : selectedBranchId,
          name: groupNameClean,
          description: p['group_description']?.toString(),
          defaultSellingPrice: defSelling,
          defaultBuyingPrice: defBuying,
          defaultCommissionType: commType,
          defaultCommissionValue: commValue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createItemGroup(newGroup);
        groupMap[groupKey] = itemGroupId;
      }

      final product = Product(
        id: newProductId,
        tenantId: tenantId,
        branchId: null,
        itemGroupId: itemGroupId,
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

      await repo.createProduct(product, targetBranchIds: targetBranchIds);

      if (initialStock > 0) {
        if (allBranchesMode) {
          for (final branch in targetBranches) {
            await repo.adjustStock(
              tenantId: tenantId,
              branchId: branch.id,
              productId: newProductId,
              adjustmentType: 'initial',
              quantityChange: initialStock,
              createdBy: createdBy,
              notes: 'Batch CSV import (all branches)',
              bundleId: bundleId,
            );
          }
        } else {
          await repo.adjustStock(
            tenantId: tenantId,
            branchId: selectedBranchId,
            productId: newProductId,
            adjustmentType: 'initial',
            quantityChange: initialStock,
            createdBy: createdBy,
            notes: 'Batch CSV import',
            bundleId: bundleId,
          );
        }
      }
    }
  }
}
