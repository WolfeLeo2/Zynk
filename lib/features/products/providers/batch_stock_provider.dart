import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/schema_models.dart';

class BatchItemState {
  final Product product;
  final int quantityChange;
  final String? notes;

  BatchItemState({
    required this.product,
    required this.quantityChange,
    this.notes,
  });

  BatchItemState copyWith({
    Product? product,
    int? quantityChange,
    String? notes,
  }) {
    return BatchItemState(
      product: product ?? this.product,
      quantityChange: quantityChange ?? this.quantityChange,
      notes: notes ?? this.notes,
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

  void updateQuantity(String productId, int newQuantity) {
    state = state.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantityChange: newQuantity);
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
