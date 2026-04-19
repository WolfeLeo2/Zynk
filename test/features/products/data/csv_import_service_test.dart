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

class MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

void main() {
  late MockPowerSyncRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(
      Category(
        id: 'fallback-category',
        tenantId: 'fallback-tenant',
        name: 'Fallback',
      ),
    );
    registerFallbackValue(
      Product(
        id: 'fallback-product',
        tenantId: 'fallback-tenant',
        name: 'Fallback Product',
        basePrice: 1,
      ),
    );
  });

  setUp(() {
    mockRepo = MockPowerSyncRepository();

    when(() => mockRepo.watchCategories()).thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.createCategory(any())).thenAnswer((_) async {});
    when(() => mockRepo.createProduct(any())).thenAnswer((_) async {});
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
      ),
    ).thenAnswer((_) async {});
    when(() => mockRepo.getBranches(any())).thenAnswer((_) async => []);
  });

  Profile buildProfile() {
    return Profile(
      id: 'profile-1',
      userId: 'user-1',
      tenantId: 'tenant-1',
      role: UserRole.owner,
      permissions: Permission.values.toSet(),
    );
  }

  ProviderContainer buildContainer({
    required String? branchId,
    Profile? profile,
  }) {
    return ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(mockRepo),
        currentBranchIdProvider.overrideWithValue(branchId),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(profile ?? buildProfile()),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> parsedProducts() {
    return [
      {
        'name': 'Tile Premium',
        'category': 'Tiles',
        'selling_price': '1200',
        'initial_stock': '5',
      },
    ];
  }

  group('CsvImportService.importProducts', () {
    test('throws when no branch is selected', () async {
      final container = buildContainer(branchId: null);
      addTearDown(container.dispose);

      await container.read(currentUserProfileProvider.future);
      final service = container.read(csvImportServiceProvider);

      await expectLater(
        service.importProducts(parsedProducts()),
        throwsA(isA<Exception>()),
      );

      verifyNever(() => mockRepo.createProduct(any()));
      verifyNever(
        () => mockRepo.adjustStock(
          tenantId: any(named: 'tenantId'),
          branchId: any(named: 'branchId'),
          productId: any(named: 'productId'),
          adjustmentType: any(named: 'adjustmentType'),
          quantityChange: any(named: 'quantityChange'),
          createdBy: any(named: 'createdBy'),
          notes: any(named: 'notes'),
        ),
      );
    });

    test('imports to selected branch in single-branch mode', () async {
      final container = buildContainer(branchId: 'branch-a');
      addTearDown(container.dispose);

      await container.read(currentUserProfileProvider.future);
      final service = container.read(csvImportServiceProvider);

      await service.importProducts(parsedProducts());

      final createdCategory =
          verify(() => mockRepo.createCategory(captureAny())).captured.single
              as Category;
      expect(createdCategory.branchId, 'branch-a');

      final createdProduct =
          verify(() => mockRepo.createProduct(captureAny())).captured.single
              as Product;
      expect(createdProduct.branchId, 'branch-a');

      verify(
        () => mockRepo.adjustStock(
          tenantId: 'tenant-1',
          branchId: 'branch-a',
          productId: any(named: 'productId'),
          adjustmentType: 'initial',
          quantityChange: 5,
          createdBy: 'user-1',
          notes: 'Batch CSV import',
        ),
      ).called(1);
      verifyNever(
        () => mockRepo.adjustStock(
          tenantId: any(named: 'tenantId'),
          branchId: 'all',
          productId: any(named: 'productId'),
          adjustmentType: any(named: 'adjustmentType'),
          quantityChange: any(named: 'quantityChange'),
          createdBy: any(named: 'createdBy'),
          notes: any(named: 'notes'),
        ),
      );
    });

    test('fans out stock to every branch in all-branches mode', () async {
      when(() => mockRepo.getBranches('tenant-1')).thenAnswer(
        (_) async => [
          Branch(id: 'branch-a', tenantId: 'tenant-1', name: 'Branch A'),
          Branch(id: 'branch-b', tenantId: 'tenant-1', name: 'Branch B'),
        ],
      );

      final container = buildContainer(branchId: 'all');
      addTearDown(container.dispose);

      await container.read(currentUserProfileProvider.future);
      final service = container.read(csvImportServiceProvider);

      await service.importProducts(parsedProducts());

      final createdCategory =
          verify(() => mockRepo.createCategory(captureAny())).captured.single
              as Category;
      expect(createdCategory.branchId, isNull);

      final createdProduct =
          verify(() => mockRepo.createProduct(captureAny())).captured.single
              as Product;
      expect(createdProduct.branchId, isNull);

      verify(
        () => mockRepo.adjustStock(
          tenantId: 'tenant-1',
          branchId: 'branch-a',
          productId: any(named: 'productId'),
          adjustmentType: 'initial',
          quantityChange: 5,
          createdBy: 'user-1',
          notes: 'Batch CSV import (all branches)',
        ),
      ).called(1);

      verify(
        () => mockRepo.adjustStock(
          tenantId: 'tenant-1',
          branchId: 'branch-b',
          productId: any(named: 'productId'),
          adjustmentType: 'initial',
          quantityChange: 5,
          createdBy: 'user-1',
          notes: 'Batch CSV import (all branches)',
        ),
      ).called(1);
    });

    test('throws when all-branches mode has no branch targets', () async {
      when(() => mockRepo.getBranches('tenant-1')).thenAnswer((_) async => []);

      final container = buildContainer(branchId: 'all');
      addTearDown(container.dispose);

      await container.read(currentUserProfileProvider.future);
      final service = container.read(csvImportServiceProvider);

      await expectLater(
        service.importProducts(parsedProducts()),
        throwsA(isA<Exception>()),
      );

      verifyNever(() => mockRepo.createProduct(any()));
      verifyNever(
        () => mockRepo.adjustStock(
          tenantId: any(named: 'tenantId'),
          branchId: any(named: 'branchId'),
          productId: any(named: 'productId'),
          adjustmentType: any(named: 'adjustmentType'),
          quantityChange: any(named: 'quantityChange'),
          createdBy: any(named: 'createdBy'),
          notes: any(named: 'notes'),
        ),
      );
    });
  });
}
