import 'package:flutter/foundation.dart';
import '../../../core/network/http_client.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/data/auth_service.dart';
import '../models/product_model.dart';
import 'market_service.dart';

/// Same shape as `MarketCartItem` in frontend/app/(public)/market/marketCartStore.ts
/// and the rows GET /api/market/cart returns.
class CartItem {
  final int id; // listing id
  final String name;
  final String category;
  final double price;
  final String currency;
  final int minOrder;
  final int quantity;
  final String? image;

  const CartItem({
    required this.id,
    required this.name,
    this.category = 'General',
    required this.price,
    this.currency = 'USD',
    this.minOrder = 1,
    required this.quantity,
    this.image,
  });

  double get lineTotal => price * quantity;

  CartItem withQuantity(int q) => CartItem(
        id: id,
        name: name,
        category: category,
        price: price,
        currency: currency,
        minOrder: minOrder,
        quantity: q < minOrder ? minOrder : q,
        image: image,
      );

  static CartItem? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = int.tryParse('${json['id']}');
    if (id == null) return null;
    final minOrder = ((json['min_order'] as num?)?.toInt() ?? 1).clamp(1, 1 << 30);
    final qty = (json['quantity'] as num?)?.toInt() ?? minOrder;
    return CartItem(
      id: id,
      name: json['name'] as String? ?? 'Untitled item',
      category: json['category'] as String? ?? 'General',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      minOrder: minOrder,
      quantity: qty < minOrder ? minOrder : qty,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': '$id',
        'name': name,
        'category': category,
        'price': price,
        'currency': currency,
        'min_order': minOrder,
        'quantity': quantity,
        'image': image,
      };

  factory CartItem.fromProduct(ProductModel p, {int? quantity}) => CartItem(
        id: p.id,
        name: p.title,
        category: p.categoryName ?? 'General',
        price: p.effectivePrice,
        currency: p.currency,
        minOrder: p.minOrder,
        quantity: quantity ?? p.minOrder,
        image: p.coverUrl,
      );
}

class CartTotals {
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;
  const CartTotals(this.subtotal, this.shipping, this.tax, this.total);

  /// Identical math to computeCartTotals (web) and the checkout service.
  factory CartTotals.of(List<CartItem> items) {
    final subtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final shipping = subtotal == 0 ? 0.0 : (subtotal > 500 ? 0.0 : 35.0);
    final tax = (subtotal * 0.06).roundToDouble();
    return CartTotals(subtotal, shipping, tax, subtotal + shipping + tax);
  }
}

/// App-wide cart. Guest → kept on device. Signed in → kept server-side
/// (store_carts) so it follows the buyer across devices and the web.
/// Every mutation updates optimistically, then reconciles with the server.
class CartStore extends ValueNotifier<List<CartItem>> {
  static final CartStore instance = CartStore._();
  CartStore._() : super(const []);

  final _api = MarketService();
  bool _initialized = false;
  Future<void>? _merging;

  int get count => value.fold(0, (s, i) => s + i.quantity);
  CartTotals get totals => CartTotals.of(value);
  String? get currency => value.isEmpty ? null : value.first.currency;

  bool contains(int listingId) => value.any((i) => i.id == listingId);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    value = _parse(await AppStorage.getGuestCart());
    if (Session.isSignedIn) mergeGuestCart();
    Session.user.addListener(() {
      if (Session.isSignedIn) {
        mergeGuestCart();
      } else {
        AppStorage.getGuestCart().then((raw) => value = _parse(raw));
      }
    });
  }

  List<CartItem> _parse(dynamic raw) =>
      raw is List ? raw.map(CartItem.fromJson).whereType<CartItem>().toList() : const [];

  void _set(List<CartItem> items, {bool fromServer = false}) {
    value = List.unmodifiable(items);
    if (!fromServer && !Session.isSignedIn) {
      AppStorage.setGuestCart(items.map((i) => i.toJson()).toList());
    }
  }

  void _sync(Future<dynamic> call) {
    call.then((res) => _set(_parse(res), fromServer: true)).catchError((Object e) {
      if (e is ApiException && e.statusCode == 401) Session.expire();
    });
  }

  Future<void> refresh() async {
    if (!Session.isSignedIn) return;
    try {
      _set(_parse(await _api.getCart()), fromServer: true);
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) Session.expire();
    }
  }

  /// Folds the guest cart into the account cart after sign-in. The server
  /// keeps the larger quantity per listing, so a retry can't double up.
  Future<void> mergeGuestCart() {
    return _merging ??= () async {
      try {
        final guest = _parse(await AppStorage.getGuestCart());
        if (guest.isEmpty) {
          await refresh();
          return;
        }
        _set(guest, fromServer: true);
        final res = await _api.mergeCart(
          guest.map((i) => {'listing_id': i.id, 'quantity': i.quantity}).toList(),
        );
        await AppStorage.setGuestCart(const []);
        _set(_parse(res), fromServer: true);
      } catch (_) {
        await refresh();
      } finally {
        _merging = null;
      }
    }();
  }

  /// First add seeds at the listing's min order; re-adding stacks on top.
  void add(CartItem item) {
    final existing = value.where((i) => i.id == item.id).firstOrNull;
    final next = existing != null
        ? value.map((i) => i.id == item.id ? i.withQuantity(i.quantity + item.quantity) : i).toList()
        : [...value, item.withQuantity(item.quantity)];
    _set(next);
    if (Session.isSignedIn) _sync(_api.addToCart(item.id, item.quantity));
  }

  void addProduct(ProductModel p, {int? quantity}) {
    add(CartItem.fromProduct(p, quantity: quantity));
    _api.trackEvent(p.id, 'cart_add');
  }

  void setQuantity(int id, int quantity) {
    final next = value.map((i) => i.id == id ? i.withQuantity(quantity) : i).toList();
    _set(next);
    final updated = next.where((i) => i.id == id).firstOrNull;
    if (Session.isSignedIn && updated != null) {
      _sync(_api.setCartQuantity(id, updated.quantity));
    }
  }

  void increment(int id) {
    final item = value.where((i) => i.id == id).firstOrNull;
    if (item != null) setQuantity(id, item.quantity + 1);
  }

  void decrement(int id) {
    final item = value.where((i) => i.id == id).firstOrNull;
    if (item != null && item.quantity > item.minOrder) setQuantity(id, item.quantity - 1);
  }

  void remove(int id) {
    _set(value.where((i) => i.id != id).toList());
    if (Session.isSignedIn) _sync(_api.removeFromCart(id));
  }

  /// After a successful checkout.
  void clear() {
    _set(const []);
    if (Session.isSignedIn) _sync(_api.clearCart());
  }

  String? imageFor(CartItem item) => MediaUrl.resolve(item.image, view: 'small');
}
