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
            return _Dock(
              index: _index,
              onSelect: (i) => i == _search ? _openSearch() : _go(i),
              items: [
                const _DockItem(Icons.storefront_outlined, Icons.storefront_rounded, 'Home'),
                const _DockItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories'),
                const _DockItem(Icons.search_rounded, Icons.search_rounded, 'Search'),
                _DockItem(Icons.favorite_border_rounded, Icons.favorite_rounded, 'Wishlist',
                    count: savedCount, badgeColor: AppColors.danger),
                _DockItem(Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Cart',
                    count: cartCount, badgeColor: p.accent),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DockItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int count;
  final Color? badgeColor;
  const _DockItem(this.icon, this.selectedIcon, this.label, {this.count = 0, this.badgeColor});
}

/// Bottom dock. Every slot gets an equal share of the width and its label
/// scales down to fit on one line, so long labels ("Categories") never
/// overflow on narrow phones or with a large system font.
class _Dock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<_DockItem> items;
  const _Dock({required this.index, required this.onSelect, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: p.card,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(child: _DockButton(item: items[i], selected: i == index, onTap: () => onSelect(i))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final _DockItem item;
  final bool selected;
  final VoidCallback onTap;
  const _DockButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = selected ? p.accent : p.textSecondary;
    final count = item.count;
    return Semantics(
      button: true,
      selected: selected,
      label: count > 0 ? '${item.label}, $count' : item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? p.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: item.badgeColor ?? p.accent,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: Icon(selected ? item.selectedIcon : item.icon, size: 22, color: color),
                ),
              ),
              const SizedBox(height: 3),
              // One line, never wider than the slot — shrinks instead of overflowing.
              SizedBox(
                height: 15,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
