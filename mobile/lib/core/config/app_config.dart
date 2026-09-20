/// App-level configuration and image URL resolution.
class AppConfig {
  AppConfig._();

  /// Backend base URL. Pass with `--dart-define=API_BASE_URL=https://...`.
  /// Defaults to the PC's LAN IP so a physical phone on the same Wi-Fi can
  /// reach the local Django dev server. For the Android emulator use
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8000` (its host loopback).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.207.34.10:8000',
  );

  /// Media domain for warehouse images, e.g. `api.xlapparals.in`.
  /// When empty, media URLs are resolved against [baseUrl].
  static const String mediaDomain = String.fromEnvironment('MEDIA_DOMAIN');

  /// Resolves an API-returned image path into a full URL.
  ///
  /// Mirrors `next.config.ts` where media images require a separate domain.
  static String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = mediaDomain.isNotEmpty ? 'https://$mediaDomain' : baseUrl;
    return '$base${path.startsWith('/') ? path : '/$path'}';
  }
}