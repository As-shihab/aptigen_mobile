import 'package:flutter/foundation.dart';
import '../../../core/storage/app_storage.dart';

/// Small on-device id lists, like the web market's localStorage stores
/// (frontend/app/lib/marketApi.ts): recently viewed and compare.
class _IdListStore extends ValueNotifier<List<int>> {
  _IdListStore(this._key, this._max) : super(const []);

  final String _key;
  final int _max;
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    value = (await AppStorage.getIdList(_key)).take(_max).toList();
  }

  void _set(List<int> ids) {
    value = ids.take(_max).toList();
    AppStorage.setIdList(_key, value);
  }
}

/// Most-recent-first listing ids the shopper has opened.
class RecentlyViewedStore extends _IdListStore {
  static final RecentlyViewedStore instance = RecentlyViewedStore._();
  RecentlyViewedStore._() : super('aptigen.market.recent.v1', 12);

  void push(int id) => _set([id, ...value.where((x) => x != id)]);
  void clear() => _set(const []);
}

/// Listings picked for side-by-side comparison (max [max]).
class CompareStore extends _IdListStore {
  static const max = 3;
  static final CompareStore instance = CompareStore._();
  CompareStore._() : super('aptigen.market.compare.v1', max);

  bool contains(int id) => value.contains(id);

  /// Returns false when the compare list is already full.
  bool toggle(int id) {
    if (value.contains(id)) {
      _set(value.where((x) => x != id).toList());
      return true;
    }
    if (value.length >= max) return false;
    _set([...value, id]);
    return true;
  }

  void clear() => _set(const []);
}

/// Coupon code the shopper applied in the cart, carried into checkout.
/// Session-only, like the web's sessionStorage coupon.
class CouponStore extends ValueNotifier<String?> {
  static final CouponStore instance = CouponStore._();
  CouponStore._() : super(null);

  void apply(String? code) {
    final c = code?.trim().toUpperCase();
    value = (c == null || c.isEmpty) ? null : c;
  }

  void clear() => value = null;
}
