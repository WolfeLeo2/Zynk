import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/domain/csv_import_analysis.dart';

final csvImportServiceProvider = Provider((ref) => CsvImportService(ref));

/// Outcome of an import, for the confirmation message.
class CsvImportResult {
  final int created;
  final int updated;
  const CsvImportResult({required this.created, required this.updated});
}

class CsvImportService {
  final Ref ref;

  CsvImportService(this.ref);

  Future<List<List<dynamic>>?> pickAndParseCsv() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        try {
          final bytes = await result.files.single.readAsBytes();
          final input = utf8.decode(bytes);
          return csv.decode(input);
        } catch (_) {
          if (result.files.single.path != null) {
            final File file = File(result.files.single.path!);
            final input = await file.readAsString();
            return csv.decode(input);
          }
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to read CSV file: $e');
    }
  }

  /// Import the analysed, non-skipped rows. Products are matched to existing
  /// ones by trimmed, case-insensitive name (SKU is optional in this app, so
  /// name is the key); unmatched rows create a new product. Stock is applied
  /// per target branch according to [mode]: `add` posts the quantity as a
  /// positive delta; `set` posts whatever delta lands each branch on the
  /// target quantity. Removal is never possible — the analyzer rejects
  /// negative quantities upstream.
  Future<CsvImportResult> importRows(
    List<ImportRow> rows,
    ImportStockMode mode, {
    required List<String> branchIds,
    String? reasonId,
  }) async {
    if (rows.isEmpty) return const CsvImportResult(created: 0, updated: 0);
    if (branchIds.isEmpty) {
      throw Exception('Select at least one branch to import into.');
    }

    final repo = ref.read(repositoryProvider);
    final profile = ref.read(currentUserProfileProvider).value;
    final tenantId = profile?.tenantId ?? 'tenant_1';

    final targetBranchIds = branchIds;
    // New products/categories/groups are tenant-wide when fanning out to more
    // than one branch, otherwise scoped to the single target branch.
    final catalogBranchId = targetBranchIds.length == 1
        ? targetBranchIds.first
        : null;
    final allBranchesMode = targetBranchIds.length > 1;

    final createdBy = profile?.userId ?? 'system';
    final bundleId = const Uuid().v4();

    // Snapshot existing catalog to resolve matches and avoid duplicate
    // categories/groups across the batch.
    final categoryMap = {
      for (final c in await repo.watchCategories().first)
        c.name.trim().toLowerCase(): c.id,
    };
    final groupMap = {
      for (final g in await repo.watchItemGroups().first)
        g.name.trim().toLowerCase(): g.id,
    };
    final productByName = {
      for (final p in await repo.watchProducts().first)
        p.name.trim().toLowerCase(): p,
    };

    // For 'set' mode we need each existing product's current stock per branch;
    // fetch it once per branch (new products start at 0).
    final existingIds = rows
        .map((r) => productByName[r.name.toLowerCase()]?.id)
        .whereType<String>()
        .toList();
    final Map<String, Map<String, num>> currentByBranch = {};
    if (mode == ImportStockMode.set) {
      for (final branchId in targetBranchIds) {
        currentByBranch[branchId] =
            await repo.getProductStockValues(existingIds, branchId);
      }
    }

    Future<String> resolveCategory(String? rawName) async {
      final name = (rawName ?? 'Uncategorized').trim();
      final key = name.toLowerCase();
      final existing = categoryMap[key];
      if (existing != null) return existing;
      final id = const Uuid().v4();
      await repo.createCategory(
        Category(
          id: id,
          tenantId: tenantId,
          branchId: catalogBranchId,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      categoryMap[key] = id;
      return id;
    }

    Future<String> resolveGroup(String? rawName) async {
      final name = (rawName ?? 'Default').trim();
      final key = name.toLowerCase();
      final existing = groupMap[key];
      if (existing != null) return existing;
      final id = const Uuid().v4();
      await repo.createItemGroup(
        ItemGroup(
          id: id,
          tenantId: tenantId,
          branchId: catalogBranchId,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      groupMap[key] = id;
      return id;
    }

    var created = 0;
    var updated = 0;

    for (final row in rows) {
      final match = productByName[row.name.toLowerCase()];
      String productId;

      if (match != null) {
        productId = match.id;
        updated++;
        // Price override: only when the CSV actually supplies a price and it
        // differs. Applies immediately (price isn't stock, so it doesn't go
        // through the pending stock-adjustment review).
        final newBase = row.sellingPrice?.toDouble();
        final newCost = row.costPrice?.toDouble();
        final changeBase = newBase != null && newBase != match.basePrice;
        final changeCost = newCost != null && newCost != match.costPrice;
        if (changeBase || changeCost) {
          await repo.updateProduct(
            match.copyWith(
              basePrice: changeBase ? newBase : match.basePrice,
              costPrice: changeCost ? newCost : match.costPrice,
              updatedAt: DateTime.now(),
            ),
          );
        }
      } else {
        productId = const Uuid().v4();
        final categoryId = await resolveCategory(row.category);
        final itemGroupId = await resolveGroup(row.itemGroup);
        final product = Product(
          id: productId,
          tenantId: tenantId,
          branchId: null,
          itemGroupId: itemGroupId,
          categoryId: categoryId,
          name: row.name,
          sku: row.sku,
          barcode: row.barcode,
          description: row.description,
          imageUrl: row.imageUrl,
          basePrice: row.sellingPrice?.toDouble(),
          costPrice: row.costPrice?.toDouble(),
          taxCategory: 'standard',
          isService: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createProduct(product, targetBranchIds: targetBranchIds);
        // Cache so a later row with the same name updates instead of duplicating.
        productByName[row.name.toLowerCase()] = product;
        created++;
      }

      for (final branchId in targetBranchIds) {
        final num delta;
        if (mode == ImportStockMode.set) {
          final current = currentByBranch[branchId]?[productId] ?? 0;
          delta = row.quantity - current;
        } else {
          delta = row.quantity;
        }
        if (delta == 0) continue;
        await repo.adjustStock(
          tenantId: tenantId,
          branchId: branchId,
          productId: productId,
          adjustmentType: mode == ImportStockMode.set
              ? 'set'
              : (match != null ? 'addition' : 'initial'),
          quantityChange: delta,
          createdBy: createdBy,
          reasonId: reasonId,
          notes: allBranchesMode
              ? 'CSV import (all branches)'
              : 'CSV import',
          bundleId: bundleId,
        );
      }
    }

    return CsvImportResult(created: created, updated: updated);
  }
}
