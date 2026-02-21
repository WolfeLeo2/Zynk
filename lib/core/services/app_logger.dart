import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Usage:
/// ```dart
/// final log = AppLogger('MyClass');
/// log.d('Debug message');
/// log.i('Info message');
/// log.w('Warning message');
/// log.e('Error message', error: e, stackTrace: stack);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  final String _tag;

  AppLogger(this._tag);

  /// Debug level - verbose information for development
  void d(String message) {
    if (kDebugMode) {
      _logger.d('[$_tag] $message');
    }
  }

  /// Info level - general information
  void i(String message) {
    _logger.i('[$_tag] $message');
  }

  /// Warning level - something unexpected but not an error
  void w(String message, {Object? error}) {
    _logger.w('[$_tag] $message', error: error);
  }

  /// Error level - something went wrong
  void e(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e('[$_tag] $message', error: error, stackTrace: stackTrace);
  }

  /// Trace level - very verbose, usually disabled
  void t(String message) {
    if (kDebugMode) {
      _logger.t('[$_tag] $message');
    }
  }
}
