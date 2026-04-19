import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/data/local/repository.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

class MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

void main() {
  late MockPowerSyncRepository mockRepo;

  setUp(() {
    mockRepo = MockPowerSyncRepository();

    when(
      () => mockRepo.watchProducts(branchId: any(named: 'branchId')),
    ).thenAnswer((_) => Stream.value(<Product>[]));

    when(
      () => mockRepo.watchProductStock(any(), branchId: any(named: 'branchId')),
    ).thenAnswer((_) => Stream.value(null));

    when(
      () => mockRepo.watchProductStockHistory(
        any(),
        branchId: any(named: 'branchId'),
      ),
    ).thenAnswer((_) => Stream.value(<StockAdjustment>[]));
  });

  ProviderContainer buildContainer(String? branchId) {
    return ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(mockRepo),
        currentBranchIdProvider.overrideWithValue(branchId),
      ],
    );
  }

  test(
    'allProductsProvider forwards selected branch to watchProducts',
    () async {
      final container = buildContainer('branch-a');
      addTearDown(container.dispose);

      await container.read(allProductsProvider.future);

      verify(() => mockRepo.watchProducts(branchId: 'branch-a')).called(1);
    },
  );

  test('stockProvider forwards selected branch to watchProductStock', () async {
    final container = buildContainer('branch-b');
    addTearDown(container.dispose);

    await container.read(stockProvider('product-1').future);

    verify(
      () => mockRepo.watchProductStock('product-1', branchId: 'branch-b'),
    ).called(1);
  });

  test(
    'stockHistoryProvider forwards selected branch to history query',
    () async {
      final container = buildContainer('all');
      addTearDown(container.dispose);

      await container.read(stockHistoryProvider('product-2').future);

      verify(
        () => mockRepo.watchProductStockHistory('product-2', branchId: 'all'),
      ).called(1);
    },
  );
}
