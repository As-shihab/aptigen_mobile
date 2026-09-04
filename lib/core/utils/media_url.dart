import '../config/app_config.dart';

/// Mirrors frontend/app/lib/media.ts `withImageView` — stored media URLs are
/// relative paths (e.g. "/public/images/x.jpg"), so this prefixes the API
/// origin when the URL isn't already absolute, and appends the same
/// `?view=small|large` sizing hint the web app uses.
class MediaUrl {
  const MediaUrl._();

  static String? resolve(String? url, {String? view}) {
    if (url == null || url.isEmpty) return null;
    final isAbsolute = RegExp(r'^https?://', caseSensitive: false).hasMatch(url);
    final absolute = isAbsolute
        ? url
        : '${AppConfig.apiBase}${url.startsWith('/') ? '' : '/'}$url';
    if (view == null) return absolute;
    return '$absolute${absolute.contains('?') ? '&' : '?'}view=$view';
  }
}
