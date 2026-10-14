import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../account/account_page.dart';
import '../market/data/cart_store.dart';
import '../market/data/wishlist_store.dart';
import '../market/presentation/cart_page.dart';
import '../market/presentation/categories_page.dart';
import '../market/presentation/home_page.dart';
import '../market/presentation/search_page.dart';
import '../market/presentation/wishlist_page.dart';

const _home = 0, _categories = 1, _search = 2, _wishlist = 3, _cart = 4;

/// Market app shell — the mobile tabs from the market design system:
/// Home · Categories · Search · Wishlist · Cart. Account opens from the
/// avatar / "Sign in" button in the home top bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = _home;
  final _searchFocus = ValueNotifier<int>(0);

  late final List<Widget> _pages = [
    HomePage(
      onBrowseCategories: () => _go(_categories),
      onSearch: _openSearch,
      onAccount: _openAccount,
    ),
    const CategoriesPage(),
    SearchPage(asTab: true, focusSignal: _searchFocus),
    WishlistPage(onShop: () => _go(_home)),
    CartPage(onShop: () => _go(_home)),
  ];

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i != _index) setState(() => _index = i);
  }

  void _openSearch() {
    _go(_search);
    _searchFocus.value++;
  }

  void _openAccount() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => AccountPage(
        onOpenWishlist: () {
          Navigator.of(ctx).pop();
          _go(_wishlist);
        },
        onOpenCart: () {
          Navigator.of(ctx).pop();
          _go(_cart);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PopScope(
      canPop: _index == _home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_home);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: ListenableBuilder(
          listenable: Listenable.merge([CartStore.instance, WishlistStore.instance]),
          builder: (_, __) {
            final cartCount = CartStore.instance.count;
            final savedCount = WishlistStore.instance.value.length;
            Widget badged(IconData icon, int count, Color color) => Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: color,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: Icon(icon),
                );
            return NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: p.card,
                indicatorColor: p.accentSoft,
                surfaceTintColor: Colors.transparent,
                height: 66,
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (s) => TextStyle(
                    fontSize: 11.5,
                    fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
                    color: s.contains(WidgetState.selected) ? p.accent : p.textSecondary,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? p.accent : p.textSecondary),
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
                child: NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => i == _search ? _openSearch() : _go(i),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront_rounded),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Categories',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.search_rounded),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: badged(Icons.favorite_border_rounded, savedCount, AppColors.danger),
                      selectedIcon: badged(Icons.favorite_rounded, savedCount, AppColors.danger),
                      label: 'Wishlist',
                    ),
                    NavigationDestination(
                      icon: badged(Icons.shopping_bag_outlined, cartCount, p.accent),
                      selectedIcon: badged(Icons.shopping_bag_rounded, cartCount, p.accent),
                      label: 'Cart',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
