import '../../../core/network/http_client.dart';
import '../models/banner_model.dart';
import '../models/category_model.dart';
import '../models/market_extras.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../models/vendor_model.dart';

class ListingsPage {
  final List<ProductModel> items;
  final int total;
  const ListingsPage({required this.items, required this.total});
}

List<Map<String, dynamic>> _rows(dynamic data) =>
    data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];

/// Every market endpoint the app uses. Public reads go to
/// /api/public/market/* (cloud's market-public.controller.ts); buyer actions
/// go to /api/market/{cart,wishlist,checkout,orders,reviews} and need a token.
class MarketService {
  final ApiClient _client;
  MarketService([ApiClient? client]) : _client = client ?? ApiClient();

  static const _pub = 'public/market/';

  // ── Public catalog ────────────────────────────────────────────────────

  /// sort: newest (default) | price_asc | price_desc | popular | rating
  /// condition: new | used | refurbished
  Future<ListingsPage> getListings({
    int skip = 0,
    int take = 20,
    String? search,
    int? categoryId,
    String? sort,
    double? minPrice,
    double? maxPrice,
    String? condition,
    int? storeId,
    bool onSale = false,
    List<int>? ids,
  }) async {
    final params = <String, String>{
      'skip': '$skip',
      'take': '$take',
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category_id': '$categoryId',
      if (sort != null && sort != 'newest') 'sort': sort,
      if (minPrice != null) 'min_price': '$minPrice',
      if (maxPrice != null) 'max_price': '$maxPrice',
      if (condition != null && condition.isNotEmpty) 'condition': condition,
      if (storeId != null) 'store_id': '$storeId',
      if (onSale) 'on_sale': 'true',
      if (ids != null && ids.isNotEmpty) 'ids': ids.take(50).join(','),
    };
    final data = await _client.get('${_pub}listings?${Uri(queryParameters: params).query}');
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final items = _rows(map['items']).map(ProductModel.fromJson).toList();
    return ListingsPage(items: items, total: (map['total'] as num?)?.toInt() ?? items.length);
  }

  Future<ProductModel?> getListing(int id) async {
    final data = await _client.get('${_pub}listing/$id');
    if (data is! Map<String, dynamic> || data['id'] == null) return null;
    return ProductModel.fromJson(data);
  }

  Future<List<CategoryModel>> getCategories() async =>
      _rows(await _client.get('${_pub}categories')).map(CategoryModel.fromJson).toList();

  Future<List<BannerModel>> getBanners(String placement) async =>
      _rows(await _client.get('${_pub}banners?placement=$placement')).map(BannerModel.fromJson).toList();

  Future<List<VendorModel>> getVendors({int take = 12}) async =>
      _rows(await _client.get('${_pub}vendors?take=$take')).map(VendorModel.fromJson).toList();

  Future<StorePageData?> getStore(int id, {int skip = 0, int take = 12, String? search}) async {
    final params = <String, String>{
      'skip': '$skip',
      'take': '$take',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final data = await _client.get('${_pub}store/$id?${Uri(queryParameters: params).query}');
    if (data is! Map<String, dynamic> || data['store'] == null) return null;
    return StorePageData.fromJson(data);
  }

  /// Flash sales live right now, each with its listings at the sale price.
  Future<List<FlashSale>> getFlashSales({int take = 24}) async =>
      _rows(await _client.get('${_pub}flash-sales?take=$take')).map(FlashSale.fromJson).toList();

  /// Server price for a cart — flash prices, promotions / coupon, shipping,
  /// tax and the payment methods every store in it accepts.
  Future<CartQuote> quote(List<Map<String, dynamic>> items, {String? couponCode}) async {
    final res = await _client.post('${_pub}quote', {
      'items': items,
      if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
    });
    return CartQuote.fromJson(res is Map<String, dynamic> ? res : const {});
  }

  Future<ReviewPage> getListingReviews(int listingId, {int skip = 0, int take = 10}) async {
    try {
      final res = await _client.get('${_pub}listing/$listingId/reviews?skip=$skip&take=$take');
      return ReviewPage.fromJson(res is Map<String, dynamic> ? res : const {});
    } catch (_) {
      return const ReviewPage();
    }
  }

  // ── Anonymous analytics (fire-and-forget, like lib/marketInsight.ts) ──

  void trackEvent(int listingId, String event, {bool unique = false}) {
    _client
        .post('${_pub}listing/$listingId/insight', {'event': event, if (unique) 'unique': true})
        .catchError((_) => null);
  }

  void trackStoreVisit(int storeId, {bool unique = false}) {
    _client.post('${_pub}store/$storeId/visit', {if (unique) 'unique': true}).catchError((_) => null);
  }

  // ── Signed-in buyer ───────────────────────────────────────────────────

  Future<dynamic> getCart() => _client.get('market/cart');
  Future<dynamic> addToCart(int listingId, int quantity) =>
      _client.post('market/cart', {'listing_id': listingId, 'quantity': quantity});
  Future<dynamic> mergeCart(List<Map<String, dynamic>> items) =>
      _client.post('market/cart/merge', {'items': items});
  Future<dynamic> setCartQuantity(int listingId, int quantity) =>
      _client.put('market/cart', listingId, {'quantity': quantity});
  Future<dynamic> removeFromCart(int listingId) => _client.delete('market/cart', listingId);
  Future<dynamic> clearCart() => _client.post('market/cart/clear', {});

  Future<List<int>> getWishlistIds() async {
    final data = await _client.get('market/wishlist/ids');
    return data is List ? data.whereType<num>().map((n) => n.toInt()).toList() : [];
  }

  /// Full saved listings (each row carries its `listing`).
  Future<List<ProductModel>> getWishlist() async => _rows(await _client.get('market/wishlist'))
      .map((r) => r['listing'])
      .whereType<Map<String, dynamic>>()
      .map(ProductModel.fromJson)
      .toList();

  /// Returns the new liked state.
  Future<bool> toggleWishlist(int listingId) async {
    final res = await _client.post('market/wishlist', {'listing_id': listingId});
    return res is Map && res['liked'] == true;
  }

  /// paymentMethod: cash | card | mobile | bank. Pass a saved [addressId]
  /// or inline [shipping] fields (full_name, phone, address, city, area,
  /// postcode). [paymentReference] is the wallet / bank transaction id.
  Future<PlacedOrder> checkout(
    List<Map<String, dynamic>> items,
    String paymentMethod, {
    int? addressId,
    Map<String, dynamic>? shipping,
    String? deliveryNote,
    String? couponCode,
    String? paymentReference,
  }) async {
    final res = await _client.post('market/checkout', {
      'items': items,
      'payment_method': paymentMethod,
      if (addressId != null) 'address_id': addressId,
      if (addressId == null && shipping != null) 'shipping': shipping,
      if (deliveryNote != null && deliveryNote.trim().isNotEmpty) 'delivery_note': deliveryNote.trim(),
      if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
      if (paymentReference != null && paymentReference.trim().isNotEmpty) 'payment_reference': paymentReference.trim(),
    });
    return PlacedOrder.fromJson(res is Map<String, dynamic> ? res : const {});
  }

  // ── Saved addresses ──────────────────────────────────────────────────

  Future<List<BuyerAddress>> getAddresses() async =>
      _rows(await _client.get('market/addresses')).map(BuyerAddress.fromJson).toList();

  Future<BuyerAddress> createAddress(AddressInput input) async =>
      BuyerAddress.fromJson(Map<String, dynamic>.from(await _client.post('market/addresses', input.toJson()) as Map));

  Future<BuyerAddress> updateAddress(int id, AddressInput input) async =>
      BuyerAddress.fromJson(Map<String, dynamic>.from(await _client.put('market/addresses', id, input.toJson()) as Map));

  /// Returns the full list after the change.
  Future<List<BuyerAddress>> setDefaultAddress(int id) async =>
      _rows(await _client.post('market/addresses/$id/default', {})).map(BuyerAddress.fromJson).toList();

  /// Returns the full list after the change.
  Future<List<BuyerAddress>> deleteAddress(int id) async =>
      _rows(await _client.delete('market/addresses', id)).map(BuyerAddress.fromJson).toList();

  // ── Refunds ──────────────────────────────────────────────────────────

  Future<List<BuyerRefund>> getMyRefunds() async =>
      _rows(await _client.get('market/refunds')).map(BuyerRefund.fromJson).toList();

  /// method: original | cash | mobile | bank
  Future<BuyerRefund> requestRefund({required int orderItemId, int? quantity, required String reason, String? method}) async {
    final res = await _client.post('market/refunds', {
      'order_item_id': orderItemId,
      if (quantity != null) 'quantity': quantity,
      'reason': reason.trim(),
      if (method != null) 'method': method,
    });
    return BuyerRefund.fromJson(res is Map<String, dynamic> ? res : const {});
  }

  Future<List<OrderModel>> getOrders() async =>
      _rows(await _client.get('market/orders')).map(OrderModel.fromJson).toList();

  Future<ItemReview?> createReview(int orderItemId, int rating, String? comment) async {
    final res = await _client.post('market/reviews', {
      'order_item_id': orderItemId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
    final row = res is Map && res['value'] is Map ? res['value'] : res;
    return ItemReview.fromJson(row);
  }
}
