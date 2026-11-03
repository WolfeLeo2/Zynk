/// Pure CSV parsing + validation + auto-fix analysis for the product/stock
/// importer. No Riverpod, no DB, no Flutter — so it's fully unit-testable.
///
/// The analyzer parses each row into typed fields, records every issue it
/// finds, and — where it safely can — computes a fixed value (e.g. stripping
/// "Ksh" / commas from a number, trimming whitespace). "Applying fixes" needs
/// no second pass: the parsed row already holds the cleaned values, so the UI
/// just shows what changed and imports the non-skipped rows.
library;

/// Whole-file stock semantics, chosen once on the import screen.
/// Removal/subtract is intentionally absent — imports can only add or set.
enum ImportStockMode { add, set }

/// One thing wrong (or auto-corrected) on a row. [fixed] non-null means the
/// analyzer already applied a safe correction and the row stays importable.
class RowIssue {
  final String field;
  final String message;
  final String? original;
  final String? fixed;

  const RowIssue({
    required this.field,
    required this.message,
    this.original,
    this.fixed,
  });

  bool get fixable => fixed != null;
}

/// A parsed CSV row. [skip] is true when a hard error (missing name, bad or
/// negative quantity) makes it unimportable.
class ImportRow {
  final int lineNumber; // 1-based line in the file, for display
  final String name;
  final String? category;
  final String? itemGroup;
  final String? sku;
  final String? barcode;
  final String? description;
  final String? imageUrl;
  final num? sellingPrice;
  final num? costPrice;
  final num quantity;
  final List<RowIssue> issues;
  final bool skip;

  const ImportRow({
    required this.lineNumber,
    required this.name,
    required this.quantity,
    required this.issues,
    required this.skip,
    this.category,
    this.itemGroup,
    this.sku,
    this.barcode,
    this.description,
    this.imageUrl,
    this.sellingPrice,
    this.costPrice,
  });

  bool get hasFixes => issues.any((i) => i.fixable);
}

class CsvAnalysis {
  final List<String> headerErrors;
  final List<ImportRow> rows;
  final List<String> detectedHeaders;

  const CsvAnalysis({
    required this.headerErrors,
    required this.rows,
    required this.detectedHeaders,
  });

  bool get ok => headerErrors.isEmpty;
  List<ImportRow> get importable => rows.where((r) => !r.skip).toList();
  int get importableCount => rows.where((r) => !r.skip).length;
  int get skippedCount => rows.where((r) => r.skip).length;
  int get fixCount =>
      rows.fold(0, (n, r) => n + r.issues.where((i) => i.fixable).length);
}

// Header aliases (all lowercased). First match wins.
const _nameKeys = ['name', 'product', 'product name', 'item', 'item name'];
const _qtyKeys = [
  'quantity',
  'qty',
  'stock',
  'initial_stock',
  'stock quantity',
];
const _priceKeys = ['selling_price', 'price', 'selling price'];
const _costKeys = ['cost_price', 'cost', 'buying_price'];
const _categoryKeys = ['category', 'categories'];
const _groupKeys = ['item_group', 'group', 'item group'];
const _skuKeys = ['sku', 'code'];
const _barcodeKeys = ['barcode'];
const _descKeys = ['description', 'desc'];
const _imageKeys = ['image_url', 'image', 'image url'];

/// Parse a number the way a spreadsheet human writes it: tolerate currency
/// symbols, thousands separators, and surrounding spaces. Returns the value
/// and whether cleaning was needed (so the UI can flag it as an auto-fix).
({num? value, bool cleaned}) _parseNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return (value: null, cleaned: false);
  final direct = num.tryParse(trimmed);
  if (direct != null) return (value: direct, cleaned: false);
  // Strip everything that isn't a digit, dot, or leading minus.
  final stripped = trimmed.replaceAll(RegExp(r'[^0-9.\-]'), '');
  final value = num.tryParse(stripped);
  return (value: value, cleaned: value != null);
}

String _numStr(num n) => n == n.truncate() ? n.toInt().toString() : n.toString();

CsvAnalysis analyzeProductCsv(List<List<dynamic>> raw) {
  if (raw.isEmpty) {
    return const CsvAnalysis(
      headerErrors: ['The file is empty.'],
      rows: [],
      detectedHeaders: [],
    );
  }

  final headers = raw.first.map((e) => e.toString().trim().toLowerCase()).toList();
  int? idxOf(List<String> keys) {
    for (final k in keys) {
      final i = headers.indexOf(k);
      if (i >= 0) return i;
    }
    return null;
  }

  final nameIdx = idxOf(_nameKeys);
  final qtyIdx = idxOf(_qtyKeys);
  final headerErrors = <String>[];
  if (nameIdx == null) headerErrors.add('Missing a "name" column.');
  if (qtyIdx == null) {
    headerErrors.add('Missing a "quantity" column (also accepts: stock, qty).');
  }
  if (headerErrors.isNotEmpty) {
    return CsvAnalysis(
      headerErrors: headerErrors,
      rows: const [],
      detectedHeaders: headers,
    );
  }

  final priceIdx = idxOf(_priceKeys);
  final costIdx = idxOf(_costKeys);
  final categoryIdx = idxOf(_categoryKeys);
  final groupIdx = idxOf(_groupKeys);
  final skuIdx = idxOf(_skuKeys);
  final barcodeIdx = idxOf(_barcodeKeys);
  final descIdx = idxOf(_descKeys);
  final imageIdx = idxOf(_imageKeys);

  final rows = <ImportRow>[];
  for (var i = 1; i < raw.length; i++) {
    final r = raw[i];
    final isBlank =
        r.isEmpty ||
        r.every((c) => c == null || c.toString().trim().isEmpty);
    if (isBlank) continue;

    String? cell(int? idx) =>
        (idx != null && idx < r.length) ? r[idx]?.toString() : null;

    final issues = <RowIssue>[];
    var skip = false;

    // Name (required)
    final rawName = cell(nameIdx) ?? '';
    final name = rawName.trim();
    if (name.isEmpty) {
      issues.add(const RowIssue(field: 'name', message: 'Name is required.'));
      skip = true;
    } else if (name != rawName) {
      issues.add(
        RowIssue(
          field: 'name',
          message: 'Trimmed whitespace.',
          original: rawName,
          fixed: name,
        ),
      );
    }

    // Quantity (required, non-negative)
    final rawQty = cell(qtyIdx) ?? '';
    num quantity = 0;
    if (rawQty.trim().isEmpty) {
      issues.add(
        const RowIssue(field: 'quantity', message: 'Quantity is required.'),
      );
      skip = true;
    } else {
      final parsed = _parseNumber(rawQty);
      if (parsed.value == null) {
        issues.add(
          RowIssue(
            field: 'quantity',
            message: '"${rawQty.trim()}" is not a number.',
          ),
        );
        skip = true;
      } else {
        quantity = parsed.value!;
        if (parsed.cleaned) {
          issues.add(
            RowIssue(
              field: 'quantity',
              message: 'Removed non-numeric characters.',
              original: rawQty.trim(),
              fixed: _numStr(quantity),
            ),
          );
        }
        if (quantity < 0) {
          issues.add(
            RowIssue(
              field: 'quantity',
              message: 'Negative stock can\'t be imported '
                  '(removing stock is not allowed).',
            ),
          );
          skip = true;
        }
      }
    }

    // Optional numeric fields: clean if present; a junk value is a warning,
    // not a skip (the product still imports without it).
    num? parseOptional(int? idx, String field, List<RowIssue> into) {
      final rawVal = cell(idx);
      if (rawVal == null || rawVal.trim().isEmpty) return null;
      final parsed = _parseNumber(rawVal);
      if (parsed.value == null) {
        into.add(
          RowIssue(
            field: field,
            message: '"${rawVal.trim()}" is not a number — ignored.',
          ),
        );
        return null;
      }
      if (parsed.cleaned) {
        into.add(
          RowIssue(
            field: field,
            message: 'Removed non-numeric characters.',
            original: rawVal.trim(),
            fixed: _numStr(parsed.value!),
          ),
        );
      }
      return parsed.value;
    }

    final sellingPrice = parseOptional(priceIdx, 'selling_price', issues);
    final costPrice = parseOptional(costIdx, 'cost_price', issues);

    String? optText(int? idx) {
      final v = cell(idx)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    rows.add(
      ImportRow(
        lineNumber: i + 1,
        name: name,
        quantity: quantity,
        category: optText(categoryIdx),
        itemGroup: optText(groupIdx),
        sku: optText(skuIdx),
        barcode: optText(barcodeIdx),
        description: optText(descIdx),
        imageUrl: optText(imageIdx),
        sellingPrice: sellingPrice,
        costPrice: costPrice,
        issues: issues,
        skip: skip,
      ),
    );
  }

  return CsvAnalysis(
    headerErrors: const [],
    rows: rows,
    detectedHeaders: headers,
  );
}
