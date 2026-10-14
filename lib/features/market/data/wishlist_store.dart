import 'package:flutter/foundation.dart';
import '../../../core/network/http_client.dart';
import '../../auth/data/auth_service.dart';
import 'market_service.dart';

/// Signed-in buyer's saved listing ids (market_wishlist_items). Empty for
/// guests — the heart prompts sign-in instead.
class WishlistStore extends ValueNotifier<Set<int>> {
  static final WishlistStore instance = WishlistStore._();
  WishlistStore._() : super(const {});

  final _api = MarketService();
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    refresh();
    Session.user.addListener(refresh);
  }

  bool has(int id) => value.contains(id);

  Future<void> refresh() async {
    if (!Session.isSignedIn) {
      value = const {};
      return;
    }
    try {
      value = (await _api.getWishlistIds()).toSet();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) Session.expire();
    }
  }

  /// Optimistic toggle; reverts if the request fails. Returns the final
  /// liked state, or null on failure.
  Future<bool?> toggle(int id) async {
    final wasLiked = value.contains(id);
    value = wasLiked ? ({...value}..remove(id)) : {...value, id};
    try {
      final liked = await _api.toggleWishlist(id);
      value = liked ? {...value, id} : ({...value}..remove(id));
      if (liked) _api.trackEvent(id, 'save');
      return liked;
    } catch (e) {
      value = wasLiked ? {...value, id} : ({...value}..remove(id));
      if (e is ApiException && e.statusCode == 401) Session.expire();
      return null;
    }
  }
}
