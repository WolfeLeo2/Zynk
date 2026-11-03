import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/schema_models.dart';

class BatchItemState {
  final Product product;
  final num quantityChange;
  final String? notes;
  // True once the user has actually typed into this row's quantity field.
  // Distinguishes an explicit "0" (valid in 'set' mode) from a row the user
  // never touched — without this, confirming a 'set' batch with untouched
  // rows silently zeroed their stock.
  final bool touched;

  BatchItemState({
    required this.product,
    required this.quantityChange,
    this.notes,
    this.touched = false,
  });

  BatchItemState copyWith({
    Product? product,
    num? quantityChange,
    String? notes,
    bool? touched,
  }) {
    return BatchItemState(
      product: product ?? this.product,
      quantityChange: quantityChange ?? this.quantityChange,
      notes: notes ?? this.notes,
      touched: touched ?? this.touched,
    );
  }
}

class BatchStockNotifier extends Notifier<List<BatchItemState>> {
  @override
  List<BatchItemState> build() => [];

  void addItem(Product product) {
    if (state.any((item) => item.product.id == product.id)) {
      return; // Already added
    }
    state = [...state, BatchItemState(product: product, quantityChange: 0)];
  }

  void updateQuantity(String productId, num newQuantity) {
    state = state.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantityChange: newQuantity, touched: true);
      }
      return item;
    }).toList();
  }

  void updateNotes(String productId, String notes) {
    state = state.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(notes: notes);
      }
      return item;
    }).toList();
  }

  void removeItem(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void clear() {
    state = [];
  }
}

final batchStockProvider =
    NotifierProvider<BatchStockNotifier, List<BatchItemState>>(
      () => BatchStockNotifier(),
    );
