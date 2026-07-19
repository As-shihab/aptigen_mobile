import 'package:flutter/material.dart';

class StoreModel {
  final int id;
  final String name;
  final String? description;
  final double rating;
  final int followerCount;
  final int productCount;
  final int joinedYear;
  final List<Color> gradient;

  const StoreModel({
    required this.id,
    required this.name,
    this.description,
    this.rating = 0.0,
    this.followerCount = 0,
    this.productCount = 0,
    this.joinedYear = 2022,
    this.gradient = const [Color(0xFF2563EB), Color(0xFF4F46E5)],
  });

  String get initials {
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}
