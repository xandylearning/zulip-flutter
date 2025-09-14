import 'package:logger/logger.dart';

/// X&Y Learning Platform logger utility.
///
/// Provides consistent logging throughout the app with appropriate
/// log levels and formatting for development and production.
class XYLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Log debug information
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log general information
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warnings
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log errors
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log verbose information (for detailed debugging)
  static void verbose(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.v(message, error: error, stackTrace: stackTrace);
  }

  /// Log what a fuck moments (for critical issues)
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Log feature usage for analytics
  static void feature(String featureName, Map<String, dynamic>? properties) {
    info('Feature used: $featureName', properties);
  }

  /// Log user actions
  static void userAction(String action, Map<String, dynamic>? context) {
    info('User action: $action', context);
  }

  /// Log API calls
  static void apiCall(String endpoint, {String? method, int? statusCode}) {
    info('API call: ${method ?? 'GET'} $endpoint', {'statusCode': statusCode});
  }

  /// Log performance metrics
  static void performance(String operation, Duration duration, [Map<String, dynamic>? details]) {
    info('Performance: $operation took ${duration.inMilliseconds}ms', details);
  }
}