import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class CartItem {
  final ProductModel product;
  final int qty;
  const CartItem({required this.product, required this.qty});
  CartItem copyWith({int? qty}) =>
      CartItem(product: product, qty: qty ?? this.qty);
}

class CartStore extends ValueNotifier<List<CartItem>> {
  static final CartStore instance = CartStore._();
  CartStore._() : super([]);

  int get itemCount => value.fold(0, (sum, e) => sum + e.qty);
  double get total =>
      value.fold(0.0, (sum, e) => sum + e.product.price * e.qty);

  void add(ProductModel product) {
    final idx = value.indexWhere((e) => e.product.id == product.id);
    if (idx >= 0) {
      final updated = List<CartItem>.from(value);
      updated[idx] = value[idx].copyWith(qty: value[idx].qty + 1);
      value = updated;
    } else {
      value = [...value, CartItem(product: product, qty: 1)];
    }
  }

  void decrement(int productId) {
    final idx = value.indexWhere((e) => e.product.id == productId);
    if (idx < 0) return;
    if (value[idx].qty <= 1) {
      remove(productId);
    } else {
      final updated = List<CartItem>.from(value);
      updated[idx] = value[idx].copyWith(qty: value[idx].qty - 1);
      value = updated;
    }
  }

  void remove(int productId) {
    value = value.where((e) => e.product.id != productId).toList();
  }

  void clear() => value = [];
}
