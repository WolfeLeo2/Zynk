import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/data/local/repository.dart';
import 'package:zynk/features/products/data/csv_import_service.dart';
import 'package:zynk/features/products/domain/csv_import_analysis.dart';

class MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

void main() {
  late MockPowerSyncRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(Category(id: 'fc', tenantId: 'ft', name: 'Fallback'));
    registerFallbackValue(
      Product(id: 'fp', tenantId: 'ft', name: 'Fallback', basePrice: 1),
    );
    registerFallbackValue(ItemGroup(id: 'fg', tenantId: 'ft', name: 'Group'));
  });

  setUp(() {
    mockRepo = MockPowerSyncRepository();
    when(() => mockRepo.watchCategories()).thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.watchItemGroups()).thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.watchProducts()).thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.createCategory(any())).thenAnswer((_) async {});
    when(() => mockRepo.createItemGroup(any())).thenAnswer((_) async {});
    when(
      () => mockRepo.createProduct(
        any(),
        targetBranchIds: any(named: 'targetBranchIds'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockRepo.updateProduct(any())).thenAnswer((_) async {});
    when(
      () => mockRepo.getProductStockValues(any(), any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockRepo.adjustStock(
        tenantId: any(named: 'tenantId'),
        branchId: any(named: 'branchId'),
        productId: any(named: 'productId'),
        adjustmentType: any(named: 'adjustmentType'),
        quantityChange: any(named: 'quantityChange'),
        createdBy: any(named: 'createdBy'),
        referenceNumber: any(named: 'referenceNumber'),
        notes: any(named: 'notes'),
        reasonId: any(named: 'reasonId'),
        bundleId: any(named: 'bundleId'),
      ),
    ).thenAnswer((_) async {});
  });

  Profile profile() => Profile(
    id: 'profile-1',
    userId: 'user-1',
    tenantId: 'tenant-1',
    role: UserRole.owner,
    permissions: Permission.values.toSet(),
  );

  Future<CsvImportService> service() async {
    final c = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(mockRepo),
        currentUserProfileProvider.overrideWith((ref) => Stream.value(profile())),
      ],
    );
    addTearDown(c.dispose);
    await c.read(currentUserProfileProvider.future);
    return c.read(csvImportServiceProvider);
  }

  List<ImportRow> oneRow({num qty = 5, String name = 'Tile Premium'}) => [
    ImportRow(
      lineNumber: 2,
      name: name,
      quantity: qty,
      category: 'Tiles',
      sellingPrice: 1200,
      issues: const [],
      skip: false,
    ),
  ];

  test('throws when no branches are given', () async {
    final s = await service();
    await expectLater(
      s.importRows(oneRow(), ImportStockMode.add, branchIds: const []),
      throwsA(isA<Exception>()),
    );
    verifyNever(
      () => mockRepo.createProduct(
        any(),
        targetBranchIds: any(named: 'targetBranchIds'),
      ),
    );
  });

  test('fans a new product out to every selected branch (add mode)', () async {
    final s = await service();
    final result = await s.importRows(
      oneRow(),
      ImportStockMode.add,
      branchIds: const ['branch-a', 'branch-b'],
    );
    expect(result.created, 1);

    for (final b in ['branch-a', 'branch-b']) {
      verify(
        () => mockRepo.adjustStock(
          tenantId: 'tenant-1',
          branchId: b,
          productId: any(named: 'productId'),
          adjustmentType: 'initial',
          quantityChange: 5,
          createdBy: 'user-1',
          notes: 'CSV import (all branches)',
          bundleId: any(named: 'bundleId'),
        ),
      ).called(1);
    }
  });

  test('new product, single branch, add mode posts the quantity', () async {
    final s = await service();
    final result = await s.importRows(
      oneRow(),
      ImportStockMode.add,
      branchIds: const ['branch-a'],
    );
    expect(result.created, 1);
    expect(result.updated, 0);
    verify(
      () => mockRepo.adjustStock(
        tenantId: 'tenant-1',
        branchId: 'branch-a',
        productId: any(named: 'productId'),
        adjustmentType: 'initial',
        quantityChange: 5,
        createdBy: 'user-1',
        notes: 'CSV import',
        bundleId: any(named: 'bundleId'),
      ),
    ).called(1);
  });

  test('existing product is updated, not duplicated', () async {
    when(() => mockRepo.watchProducts()).thenAnswer(
      (_) => Stream.value([
        Product(id: 'p1', tenantId: 'tenant-1', name: 'Tile Premium'),
      ]),
    );
    final s = await service();
    final result = await s.importRows(
      oneRow(),
      ImportStockMode.add,
      branchIds: const ['branch-a'],
    );
    expect(result.created, 0);
    expect(result.updated, 1);
    verifyNever(
      () => mockRepo.createProduct(
        any(),
        targetBranchIds: any(named: 'targetBranchIds'),
      ),
    );
    verify(
      () => mockRepo.adjustStock(
        tenantId: 'tenant-1',
        branchId: 'branch-a',
        productId: 'p1',
        adjustmentType: 'addition',
        quantityChange: 5,
        createdBy: 'user-1',
        notes: 'CSV import',
        bundleId: any(named: 'bundleId'),
      ),
    ).called(1);
  });

  test('set mode posts the delta to reach the target (30 → 20 = -10)', () async {
    when(() => mockRepo.watchProducts()).thenAnswer(
      (_) => Stream.value([
        Product(id: 'p1', tenantId: 'tenant-1', name: 'Tile Premium'),
      ]),
    );
    when(
      () => mockRepo.getProductStockValues(['p1'], 'branch-a'),
    ).thenAnswer((_) async => {'p1': 30});

    final s = await service();
    await s.importRows(
      oneRow(qty: 20),
      ImportStockMode.set,
      branchIds: const ['branch-a'],
    );
    verify(
      () => mockRepo.adjustStock(
        tenantId: 'tenant-1',
        branchId: 'branch-a',
        productId: 'p1',
        adjustmentType: 'set',
        quantityChange: -10,
        createdBy: 'user-1',
        notes: 'CSV import',
        bundleId: any(named: 'bundleId'),
      ),
    ).called(1);
  });

  test('forwards the reason to the pending stock adjustment', () async {
    final s = await service();
    await s.importRows(
      oneRow(),
      ImportStockMode.add,
      branchIds: const ['branch-a'],
      reasonId: 'reason-9',
    );
    verify(
      () => mockRepo.adjustStock(
        tenantId: 'tenant-1',
        branchId: 'branch-a',
        productId: any(named: 'productId'),
        adjustmentType: 'initial',
        quantityChange: 5,
        createdBy: 'user-1',
        reasonId: 'reason-9',
        notes: 'CSV import',
        bundleId: any(named: 'bundleId'),
      ),
    ).called(1);
  });

  test('overrides an existing product price when the CSV supplies a new one', () async {
    when(() => mockRepo.watchProducts()).thenAnswer(
      (_) => Stream.value([
        Product(
          id: 'p1',
          tenantId: 'tenant-1',
          name: 'Tile Premium',
          basePrice: 1000,
        ),
      ]),
    );
    final s = await service();
    // oneRow() carries sellingPrice: 1200, which differs from 1000.
    await s.importRows(
      oneRow(),
      ImportStockMode.add,
      branchIds: const ['branch-a'],
    );
    verify(
      () => mockRepo.updateProduct(
        any(
          that: isA<Product>().having((p) => p.basePrice, 'basePrice', 1200),
        ),
      ),
    ).called(1);
  });

  test('does not touch price when the CSV omits it', () async {
    when(() => mockRepo.watchProducts()).thenAnswer(
      (_) => Stream.value([
        Product(
          id: 'p1',
          tenantId: 'tenant-1',
          name: 'NoPrice',
          basePrice: 1000,
        ),
      ]),
    );
    final s = await service();
    await s.importRows(
      [
        ImportRow(
          lineNumber: 2,
          name: 'NoPrice',
          quantity: 5,
          issues: const [],
          skip: false,
        ),
      ],
      ImportStockMode.add,
      branchIds: const ['branch-a'],
    );
    verifyNever(() => mockRepo.updateProduct(any()));
  });

  test('set mode with target == current writes nothing', () async {
    when(() => mockRepo.watchProducts()).thenAnswer(
      (_) => Stream.value([
        Product(id: 'p1', tenantId: 'tenant-1', name: 'Tile Premium'),
      ]),
    );
    when(
      () => mockRepo.getProductStockValues(['p1'], 'branch-a'),
    ).thenAnswer((_) async => {'p1': 20});

    final s = await service();
    await s.importRows(
      oneRow(qty: 20),
      ImportStockMode.set,
      branchIds: const ['branch-a'],
    );
    verifyNever(
      () => mockRepo.adjustStock(
        tenantId: any(named: 'tenantId'),
        branchId: any(named: 'branchId'),
        productId: any(named: 'productId'),
        adjustmentType: any(named: 'adjustmentType'),
        quantityChange: any(named: 'quantityChange'),
        createdBy: any(named: 'createdBy'),
        notes: any(named: 'notes'),
        bundleId: any(named: 'bundleId'),
      ),
    );
  });
}
