import 'package:logging/logging.dart' as logging;

/// Thin wrapper around `package:logging` giving every layer a consistently
/// named, local-only logger (§15.4 — zero telemetry by default).
class AppLogger {
  /// Creates a logger scoped to [name] (typically the owning class/feature).
  AppLogger(String name) : _logger = logging.Logger(name);

  final logging.Logger _logger;

  static bool _initialized = false;

  /// Wires the root logger to print records. Call once at app startup.
  static void init({logging.Level level = logging.Level.INFO}) {
    if (_initialized) return;
    _initialized = true;
    logging.Logger.root.level = level;
    logging.Logger.root.onRecord.listen((record) {
      // Local-only sink (§15.4): stdout today, replaced by a file sink once
      // the local-logs viewer/export lands (Phase 10).
      // ignore: avoid_print
      print('[${record.level.name}] ${record.loggerName}: ${record.message}');
    });
  }

  /// Logs a fine-grained diagnostic message.
  void fine(String message) => _logger.fine(message);

  /// Logs an informational message.
  void info(String message) => _logger.info(message);

  /// Logs a warning, optionally with the triggering [error]/[stackTrace].
  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.warning(message, error, stackTrace);

  /// Logs a severe error, optionally with the triggering [error]/[stackTrace].
  void severe(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
