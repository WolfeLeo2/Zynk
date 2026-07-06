import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/features/products/domain/csv_import_analysis.dart';

void main() {
  group('header validation', () {
    test('empty file is a header error', () {
      final a = analyzeProductCsv([]);
      expect(a.ok, isFalse);
      expect(a.headerErrors, isNotEmpty);
    });

    test('missing name column is rejected', () {
      final a = analyzeProductCsv([
        ['quantity'],
        ['5'],
      ]);
      expect(a.ok, isFalse);
      expect(a.headerErrors.join(), contains('name'));
    });

    test('missing quantity column is rejected', () {
      final a = analyzeProductCsv([
        ['name'],
        ['Tile'],
      ]);
      expect(a.ok, isFalse);
      expect(a.headerErrors.join(), contains('quantity'));
    });

    test('accepts "stock" and "qty" as quantity aliases', () {
      expect(
        analyzeProductCsv([
          ['name', 'stock'],
          ['Tile', '5'],
        ]).ok,
        isTrue,
      );
      expect(
        analyzeProductCsv([
          ['Name', 'QTY'],
          ['Tile', '5'],
        ]).ok,
        isTrue,
      );
    });
  });

  group('row parsing + auto-fix', () {
    CsvAnalysis parse(List<List<dynamic>> extraRows) => analyzeProductCsv([
      ['name', 'quantity', 'selling_price'],
      ...extraRows,
    ]);

    test('clean row has no issues and is importable', () {
      final a = parse([
        ['Ceramic Tile', '50', '1200'],
      ]);
      final row = a.rows.single;
      expect(row.skip, isFalse);
      expect(row.issues, isEmpty);
      expect(row.name, 'Ceramic Tile');
      expect(row.quantity, 50);
      expect(row.sellingPrice, 1200);
    });

    test('trims whitespace on name as a fixable issue', () {
      final a = parse([
        ['  Ceramic Tile  ', '50', '1200'],
      ]);
      final row = a.rows.single;
      expect(row.name, 'Ceramic Tile');
      expect(row.skip, isFalse);
      expect(row.issues.any((i) => i.field == 'name' && i.fixable), isTrue);
    });

    test('strips thousands separators from quantity', () {
      final a = parse([
        ['Tile', '1,250', '1200'],
      ]);
      final row = a.rows.single;
      expect(row.quantity, 1250);
      expect(row.skip, isFalse);
      expect(row.hasFixes, isTrue);
    });

    test('strips currency symbols from price', () {
      final a = parse([
        ['Tile', '5', 'Ksh 1,200'],
      ]);
      final row = a.rows.single;
      expect(row.sellingPrice, 1200);
      expect(row.skip, isFalse); // price cleaned, still importable
    });

    test('supports fractional stock', () {
      final a = parse([
        ['Toilet', '1.5', '8500'],
      ]);
      expect(a.rows.single.quantity, 1.5);
    });

    test('negative quantity is rejected (no stock removal via import)', () {
      final a = parse([
        ['Tile', '-5', '1200'],
      ]);
      final row = a.rows.single;
      expect(row.skip, isTrue);
      expect(
        row.issues.any((i) => i.field == 'quantity' && !i.fixable),
        isTrue,
      );
    });

    test('missing name skips the row', () {
      final a = parse([
        ['', '5', '1200'],
      ]);
      expect(a.rows.single.skip, isTrue);
    });

    test('non-numeric quantity skips the row', () {
      final a = parse([
        ['Tile', 'abc', '1200'],
      ]);
      expect(a.rows.single.skip, isTrue);
    });

    test('junk price is a warning, not a skip', () {
      final a = parse([
        ['Tile', '5', 'call us'],
      ]);
      final row = a.rows.single;
      expect(row.skip, isFalse);
      expect(row.sellingPrice, isNull);
      expect(row.issues.any((i) => i.field == 'selling_price'), isTrue);
    });

    test('blank rows are ignored', () {
      final a = parse([
        ['Tile', '5', '1200'],
        ['', '', ''],
        [],
      ]);
      expect(a.rows.length, 1);
    });
  });

  group('analysis counts', () {
    test('tallies importable, skipped, and fix counts', () {
      final a = analyzeProductCsv([
        ['name', 'quantity'],
        ['Good', '10'], // clean
        ['  Fixme  ', '1,000'], // 2 fixes (trim + comma), importable
        ['', '5'], // skipped (no name)
        ['Neg', '-3'], // skipped (negative)
      ]);
      expect(a.importableCount, 2);
      expect(a.skippedCount, 2);
      expect(a.fixCount, 2);
    });
  });
}
