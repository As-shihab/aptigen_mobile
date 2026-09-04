import '../../../core/network/http_client.dart';
import '../models/banner_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../models/vendor_model.dart';

class ListingsPage {
  final List<ProductModel> items;
  final int total;
  const ListingsPage({required this.items, required this.total});
}

/// Talks to the real, unauthenticated market API — cloud's
/// market-public.controller.ts, mounted at /api/public/market — the same
/// backend frontend/app/(public)/market/MarketClient.tsx consumes.
class MarketService {
  final ApiClient _client;
  MarketService(this._client);

  static const _base = 'public/market/';

  Future<ListingsPage> getListings({
    int skip = 0,
    int take = 20,
    String? search,
    int? categoryId,
  }) async {
    final params = <String, String>{
      'skip': '$skip',
      'take': '$take',
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category_id': '$categoryId',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final data = await _client.get('$_base' 'listings?$query', isV8: false);
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final items = ((map['items'] as List?) ?? [])
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return ListingsPage(items: items, total: map['total'] as int? ?? items.length);
  }

  Future<ProductModel?> getListing(int id) async {
    final data = await _client.get('$_base' 'listing/$id', isV8: false);
    if (data is! Map<String, dynamic>) return null;
    return ProductModel.fromJson(data);
  }

  Future<List<CategoryModel>> getCategories() async {
    final data = await _client.get('$_base' 'categories', isV8: false);
    return ((data as List?) ?? [])
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BannerModel>> getBanners(String placement) async {
    final data = await _client.get('$_base' 'banners?placement=$placement', isV8: false);
    return ((data as List?) ?? [])
        .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VendorModel>> getVendors({int take = 12}) async {
    final data = await _client.get('$_base' 'vendors?take=$take', isV8: false);
    return ((data as List?) ?? [])
        .map((e) => VendorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StorePageData?> getStore(int id) async {
    final data = await _client.get('$_base' 'store/$id', isV8: false);
    if (data is! Map<String, dynamic> || data['store'] == null) return null;
    return StorePageData.fromJson(data);
  }

  /// Anonymous analytics ping — best-effort, never surfaces a failure to the
  /// caller (mirrors trackListingEvent in frontend/app/lib/marketInsight.ts).
  Future<void> trackEvent(int listingId, String event, {bool unique = false}) async {
    try {
      await _client.post('$_base' 'listing/$listingId/insight', {
        'event': event,
        if (unique) 'unique': true,
      }, isV8: false);
    } catch (_) {
      // best-effort
    }
  }
}
