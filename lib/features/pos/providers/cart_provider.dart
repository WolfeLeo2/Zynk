import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CART STATE
// ─────────────────────────────────────────────────────────────────────────────

class CartState {
  final List<PosCartItem> items;

  const CartState({this.items = const []});

  double get total => items.fold(0, (sum, i) => sum + i.total);
  num get totalQuantity => items.fold<num>(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<PosCartItem>? items}) =>
      CartState(items: items ?? this.items);
}

// ─────────────────────────────────────────────────────────────────────────────
// CART NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addItem(
    Product product, {
    ItemGroup? itemGroup,
    num availableStock = 999,
  }) {
    final items = List<PosCartItem>.from(state.items);
    final idx = items.indexWhere((i) => i.product.id == product.id);
    final inCart = idx != -1 ? items[idx].quantity : 0;

    // Step by a whole unit, but never past what's in stock — a product with
    // only 0.5 left must still be addable (as 0.5), not blocked because a
    // full unit won't fit. Services are unlimited.
    final step = product.isService
        ? 1
        : _stepWithin(availableStock - inCart);
    if (step == null) return; // nothing left — caller surfaces a snackbar

    if (idx != -1) {
      items[idx].quantity += step;
    } else {
      items.add(
        PosCartItem(product: product, itemGroup: itemGroup, quantity: step),
      );
    }

    state = state.copyWith(items: items);
  }

  /// The largest whole-or-fractional unit that fits in [remaining], or null
  /// when there is nothing left to add.
  static num? _stepWithin(num remaining) {
    if (remaining <= 0) return null;
    return remaining < 1 ? remaining : 1;
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.product.id != productId).toList(),
    );
  }

  void setQuantity(String productId, num qty) {
    if (qty <= 0) {
      removeItem(productId);
      return;
    }
    final items = List<PosCartItem>.from(state.items);
    final idx = items.indexWhere((i) => i.product.id == productId);
    if (idx != -1) {
      items[idx].quantity = qty;
    }
    state = state.copyWith(items: items);
  }

  void clear() => state = const CartState();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Global, persistent cart. Survives navigation (unlike widget-local state).
final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
