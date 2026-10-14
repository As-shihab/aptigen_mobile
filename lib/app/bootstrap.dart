import 'package:flutter/material.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/data/auth_service.dart';
import '../features/market/data/cart_store.dart';
import '../features/market/data/wishlist_store.dart';

void bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppController.init();
  await Session.restore();
  await CartStore.instance.init();
  WishlistStore.instance.init();
  runApp(builder());
}
