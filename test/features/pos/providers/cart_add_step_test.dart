import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';

Product _product({bool isService = false}) => Product(
  id: 'p1',
  tenantId: 't1',
  name: 'Test Toilet Suite',
  isService: isService,
);

num? _qtyAfterAdds(
  ProviderContainer container,
  Product product,
  num availableStock,
  int adds,
) {
  for (var i = 0; i < adds; i++) {
    container
        .read(cartProvider.notifier)
        .addItem(product, availableStock: availableStock);
  }
  final items = container.read(cartProvider).items;
  return items.isEmpty ? null : items.first.quantity;
}

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('CartNotifier.addItem — fractional stock', () {
    // The reported bug: 0.5 in stock was unaddable because the cart always
    // stepped by a full unit and 1 > 0.5 failed the guard.
    test('adds the fractional remainder when less than one unit is left', () {
      expect(_qtyAfterAdds(container, _product(), 0.5, 1), 0.5);
    });

    test('a second tap cannot exceed the fractional stock', () {
      expect(_qtyAfterAdds(container, _product(), 0.5, 3), 0.5);
    });

    test('steps by whole units while a full unit still fits', () {
      expect(_qtyAfterAdds(container, _product(), 4.5, 1), 1);
      expect(container.read(cartProvider).items.first.quantity, 1);
    });

    test('tops up with the leftover fraction at the stock ceiling', () {
      // 4.5 in stock: 1,1,1,1 then the trailing 0.5 — never 5.
      expect(_qtyAfterAdds(container, _product(), 4.5, 6), 4.5);
    });

    test('zero stock adds nothing at all', () {
      expect(_qtyAfterAdds(container, _product(), 0, 1), isNull);
    });

    test('negative stock (an oversold row) adds nothing', () {
      expect(_qtyAfterAdds(container, _product(), -1, 1), isNull);
    });

    test('services ignore stock entirely', () {
      expect(_qtyAfterAdds(container, _product(isService: true), 0, 3), 3);
    });
  });
}
