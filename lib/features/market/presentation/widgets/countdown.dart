import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One shared one-second clock for every countdown on screen — a grid of
/// flash-sale cards listens to the same timer instead of each starting its
/// own (port of `useNow` in components/market/FlashCountdown.tsx). The timer
/// only runs while something is listening.
class MarketClock extends ChangeNotifier implements ValueListenable<DateTime> {
  MarketClock._();
  static final MarketClock instance = MarketClock._();

  Timer? _timer;
  DateTime _now = DateTime.now();
  int _listeners = 0;

  @override
  DateTime get value => _timer == null ? DateTime.now() : _now;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    if (_timer == null) {
      _now = DateTime.now();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _now = DateTime.now();
        notifyListeners();
      });
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners = (_listeners - 1).clamp(0, 1 << 30);
    if (_listeners == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// HH:MM:SS (hours not capped at 24).
String formatHms(Duration left) {
  final total = left.isNegative ? 0 : left.inSeconds;
  return '${_pad(total ~/ 3600)}:${_pad((total % 3600) ~/ 60)}:${_pad(total % 60)}';
}

/// Compact remaining time for small spaces: "2d 4h", "3h 12m", "8m 05s".
String formatShort(Duration left) {
  final total = left.isNegative ? 0 : left.inSeconds;
  final d = total ~/ 86400;
  final h = (total % 86400) ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${_pad(m)}m';
  return '${m}m ${_pad(s)}s';
}

/// Rebuilds every second with the time left until [endsAt] (never negative).
class CountdownBuilder extends StatelessWidget {
  final DateTime endsAt;
  final Widget Function(BuildContext context, Duration left) builder;
  const CountdownBuilder({super.key, required this.endsAt, required this.builder});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
        valueListenable: MarketClock.instance,
        builder: (context, now, _) {
          final left = endsAt.difference(now);
          return builder(context, left.isNegative ? Duration.zero : left);
        },
      );
}

enum CountdownFormat { hms, short }

/// Live countdown text to [endsAt]: HH:MM:SS (strips, product page) or
/// "3h 12m" (cards). [prefix] is dropped once the time runs out.
class Countdown extends StatelessWidget {
  final DateTime endsAt;
  final CountdownFormat format;
  final String prefix;
  final String endedLabel;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const Countdown({
    super.key,
    required this.endsAt,
    this.format = CountdownFormat.hms,
    this.prefix = '',
    this.endedLabel = 'Ended',
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) => CountdownBuilder(
        endsAt: endsAt,
        builder: (context, left) {
          final text = left == Duration.zero
              ? endedLabel
              : '$prefix${format == CountdownFormat.hms ? formatHms(left) : formatShort(left)}';
          return Text(
            text,
            maxLines: maxLines,
            overflow: overflow,
            style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          );
        },
      );
}
