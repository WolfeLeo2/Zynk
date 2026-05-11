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
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
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

  void addItem(Product product, {ItemGroup? itemGroup, int availableStock = 999}) {
    final items = List<PosCartItem>.from(state.items);
    final idx = items.indexWhere((i) => i.product.id == product.id);

    if (idx != -1) {
      // Already in cart — check stock before incrementing
      if (!product.isService && items[idx].quantity + 1 > availableStock) {
        // Cannot add — caller should surface a snackbar
        return;
      }
      items[idx].quantity++;
    } else {
      items.add(PosCartItem(product: product, itemGroup: itemGroup));
    }

    state = state.copyWith(items: items);
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.product.id != productId).toList(),
    );
  }

  void setQuantity(String productId, int qty) {
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
