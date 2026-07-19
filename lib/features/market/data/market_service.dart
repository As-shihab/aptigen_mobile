import 'package:flutter/material.dart';
import '../../../core/network/http_client.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';

class MarketService {
  final ApiClient _client;
  MarketService(this._client);

  Future<List<ProductModel>> getProducts({String? category}) async {
    try {
      final filter =
          (category != null && category != 'All') ? "&\$filter=category eq '$category'" : '';
      final data = await _client.get(
        'market_products?\$top=100&\$orderby=is_featured desc,id desc$filter',
      );
      final list = data is List
          ? data
          : (data as Map<String, dynamic>?)?['value'] as List? ?? [];
      final products =
          (list as List).map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
      return products.isEmpty ? _fallback(category) : products;
    } catch (_) {
      return _fallback(category);
    }
  }

  Future<List<ProductModel>> getProductsBySeller(int sellerId) async {
    final all = await getProducts();
    return all.where((p) => p.sellerId == sellerId).toList();
  }

  List<ProductModel> _fallback(String? category) {
    if (category != null && category != 'All') {
      return _mock.where((p) => p.category == category).toList();
    }
    return _mock;
  }

  static StoreModel? getStoreById(int id) =>
      _stores.where((s) => s.id == id).firstOrNull;

  static final _stores = [
    const StoreModel(
      id: 1,
      name: 'Apple Premium',
      description: 'Official Apple reseller. Genuine products, expert support, and same-day delivery.',
      rating: 4.9,
      followerCount: 128400,
      productCount: 4,
      joinedYear: 2019,
      gradient: [Color(0xFF2563EB), Color(0xFF4F46E5)],
    ),
    const StoreModel(
      id: 2,
      name: 'Audio Hub',
      description: 'Your one-stop shop for premium headphones, earbuds, and speakers.',
      rating: 4.7,
      followerCount: 45200,
      productCount: 2,
      joinedYear: 2020,
      gradient: [Color(0xFF7C3AED), Color(0xFF9333EA)],
    ),
    const StoreModel(
      id: 3,
      name: 'Tech Universe',
      description: 'Wide range of monitors, keyboards, and peripherals for every setup.',
      rating: 4.6,
      followerCount: 32800,
      productCount: 2,
      joinedYear: 2021,
      gradient: [Color(0xFF0891B2), Color(0xFF2563EB)],
    ),
    const StoreModel(
      id: 4,
      name: 'Active Gear Co.',
      description: 'Fitness wearables and GPS devices for athletes and adventurers.',
      rating: 4.5,
      followerCount: 21600,
      productCount: 2,
      joinedYear: 2021,
      gradient: [Color(0xFF059669), Color(0xFF0D9488)],
    ),
  ];

  static final _mock = [
    const ProductModel(
      id: 1, name: 'MacBook Pro M3', price: 1299, category: 'Tech',
      rating: 4.9, reviewCount: 234, brand: 'Apple', isFeatured: true,
      sellerId: 1, sellerName: 'Apple Premium',
      description: 'The most powerful MacBook Pro ever. With M3 chip, up to 22 hours battery life and a stunning Liquid Retina XDR display.',
    ),
    const ProductModel(
      id: 2, name: 'Sony WH-1000XM5', price: 299, originalPrice: 349,
      category: 'Audio', rating: 4.8, reviewCount: 521, brand: 'Sony',
      isFeatured: true, sellerId: 2, sellerName: 'Audio Hub',
      description: 'Industry-leading noise cancellation. Crystal clear hands-free calling with 4 beamforming microphones.',
    ),
    const ProductModel(
      id: 3, name: 'Apple Watch Series 9', price: 399, category: 'Wearables',
      rating: 4.7, reviewCount: 189, brand: 'Apple', isFeatured: true,
      sellerId: 1, sellerName: 'Apple Premium',
      description: 'The most advanced Apple Watch yet. With double tap gesture and improved health sensors.',
    ),
    const ProductModel(
      id: 4, name: 'iPad Air M2', price: 599, originalPrice: 699,
      category: 'Tech', rating: 4.8, reviewCount: 312, brand: 'Apple',
      sellerId: 1, sellerName: 'Apple Premium',
      description: 'Supercharged by M2 chip. Versatile for work, learning, and creative projects.',
    ),
    const ProductModel(
      id: 5, name: 'AirPods Pro 2', price: 249, category: 'Audio',
      rating: 4.9, reviewCount: 891, brand: 'Apple',
      sellerId: 1, sellerName: 'Apple Premium',
      description: 'Up to 2× more noise cancellation than the original AirPods Pro. Adaptive Audio.',
    ),
    const ProductModel(
      id: 6, name: 'Garmin Fenix 7', price: 599, originalPrice: 799,
      category: 'Wearables', rating: 4.6, reviewCount: 145, brand: 'Garmin',
      sellerId: 4, sellerName: 'Active Gear Co.',
      description: 'Multi-sport GPS smartwatch with solar charging, adventure-ready durability.',
    ),
    const ProductModel(
      id: 7, name: 'Samsung 4K Monitor', price: 449, category: 'Tech',
      rating: 4.7, reviewCount: 267, brand: 'Samsung',
      sellerId: 3, sellerName: 'Tech Universe',
      description: '32" 4K UHD IPS panel, 144Hz refresh rate, HDR600, USB-C 90W charging.',
    ),
    const ProductModel(
      id: 8, name: 'Bose QuietComfort 45', price: 149, originalPrice: 199,
      category: 'Audio', rating: 4.5, reviewCount: 443, brand: 'Bose',
      sellerId: 2, sellerName: 'Audio Hub',
      description: 'Acclaimed noise cancellation in a comfortable, foldable design.',
    ),
    const ProductModel(
      id: 9, name: 'Fitbit Sense 2', price: 249, category: 'Wearables',
      rating: 4.4, reviewCount: 312, brand: 'Fitbit',
      sellerId: 4, sellerName: 'Active Gear Co.',
      description: 'Advanced health smartwatch with continuous EDA scanning and built-in GPS.',
    ),
    const ProductModel(
      id: 10, name: 'Keychron K2 Pro', price: 109, category: 'Tech',
      rating: 4.8, reviewCount: 678, brand: 'Keychron',
      sellerId: 3, sellerName: 'Tech Universe',
      description: 'Compact wireless mechanical keyboard. QMK/VIA compatible, RGB backlight.',
    ),
  ];
}
