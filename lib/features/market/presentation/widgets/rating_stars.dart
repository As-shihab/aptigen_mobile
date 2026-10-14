import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Read-only star rating (0–5, halves rounded) with an optional "(count)" —
/// port of components/market/RatingStars.tsx.
class RatingStars extends StatelessWidget {
  final double? value;
  final int? count;
  final double size;
  const RatingStars({super.key, required this.value, this.count, this.size = 13});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final v = (value ?? 0).clamp(0, 5).toDouble();
    final empty = p.isDark ? p.fill : const Color(0xFFE5E7EB);
    return Semantics(
      label: value == null ? 'No ratings yet' : '${v.toStringAsFixed(1)} out of 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  Icon(Icons.star_rounded, size: size, color: empty),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: (((v - (i - 1)).clamp(0, 1) * 2).round() / 2).toDouble(),
                      child: Icon(Icons.star_rounded, size: size, color: const Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text('($count)', style: TextStyle(fontSize: 11, height: 1.2, color: p.textSecondary)),
          ],
        ],
      ),
    );
  }
}
