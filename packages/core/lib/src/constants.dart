/// App-wide constant values shared across packages.
abstract final class AppConstants {
  /// The product name shown in the UI, window title, and user agent.
  static const String appName = 'Fluent Music';

  /// The current app version.
  static const String appVersion = '0.1.0';

  /// The HTTP `User-Agent` sent with outbound requests.
  static const String userAgent = 'FluentMusic/$appVersion (Windows)';
}
