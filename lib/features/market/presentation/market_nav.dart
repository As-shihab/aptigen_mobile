import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_model.dart';
import 'compare_page.dart';
import 'flash_sales_page.dart';
import 'product_page.dart';
import 'search_page.dart';
import 'store_page.dart';

void openProduct(BuildContext context, int id, {ProductModel? preview}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductPage(id: id, preview: preview)));
}

void openStore(BuildContext context, int id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => StorePage(id: id)));
}

void openSearch(BuildContext context, {String? query, int? categoryId, String? categoryName, bool onSale = false}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SearchPage(initialQuery: query, categoryId: categoryId, categoryName: categoryName, onSale: onSale),
  ));
}

void openFlashSales(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlashSalesPage()));
}

void openCompare(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComparePage()));
}

Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Banner `link_url`s are web paths (`/market/view?id=5`,
/// `/market/store?id=3`, `/market?category_id=2`, `/market?q=shoes`) or
/// full external links — route each to the matching native screen.
void openMarketLink(BuildContext context, String? link) {
  if (link == null || link.trim().isEmpty || link == '#') return;
  final uri = Uri.tryParse(link.trim());
  if (uri == null) return;
  final isExternal = uri.hasScheme && !uri.host.contains('aptigen');
  if (isExternal) {
    openExternal(link);
    return;
  }
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  final id = int.tryParse(uri.queryParameters['id'] ?? '');
  if (path.endsWith('/market/view') && id != null) return openProduct(context, id);
  if (path.endsWith('/market/store') && id != null) return openStore(context, id);
  if (path.endsWith('/market/flash-sales')) return openFlashSales(context);
  if (path.endsWith('/market/compare')) return openCompare(context);
  final cat = int.tryParse(uri.queryParameters['category_id'] ?? '');
  final q = uri.queryParameters['q'];
  final sale = uri.queryParameters['on_sale'];
  final onSale = sale == '1' || sale == 'true';
  if (cat != null || (q != null && q.isNotEmpty) || onSale || path.endsWith('/market/search')) {
    return openSearch(context, query: q, categoryId: cat, onSale: onSale);
  }
  if (uri.hasScheme) openExternal(link);
}
