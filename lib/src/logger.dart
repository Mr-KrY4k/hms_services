/// Логгер для плагина hms_services.
///
/// Выводит логи только в режиме отладки (debug mode).
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as logger_pkg;

/// Глобальный экземпляр логгера.
final _logger = logger_pkg.Logger(
  printer: _CustomLogPrinter(),
  level: kDebugMode ? logger_pkg.Level.debug : logger_pkg.Level.off,
);

/// Кастомный принтер для логов с префиксом плагина.
class _CustomLogPrinter extends logger_pkg.LogPrinter {
  static const String _prefix = '[hms_services]';

  @override
  List<String> log(logger_pkg.LogEvent event) {
    final color = _getColor(event.level);
    final emoji = _getEmoji(event.level);
    final levelName = _getLevelName(event.level);

    return ['$color$_prefix $emoji [$levelName] ${event.message}$_reset'];
  }

  String _getColor(logger_pkg.Level level) {
    if (!kDebugMode) return '';
    switch (level) {
      case logger_pkg.Level.trace:
      case logger_pkg.Level.verbose: // ignore: deprecated_member_use
        return '\x1B[90m'; // Серый
      case logger_pkg.Level.debug:
        return '\x1B[36m'; // Голубой
      case logger_pkg.Level.info:
        return '\x1B[32m'; // Зеленый
      case logger_pkg.Level.warning:
        return '\x1B[33m'; // Желтый
      case logger_pkg.Level.error:
        return '\x1B[31m'; // Красный
      case logger_pkg.Level.fatal:
      case logger_pkg.Level.wtf: // ignore: deprecated_member_use
        return '\x1B[35m'; // Пурпурный
      case logger_pkg.Level.all:
      case logger_pkg.Level.off:
      case logger_pkg.Level.nothing: // ignore: deprecated_member_use
        return '';
    }
  }

  String _getEmoji(logger_pkg.Level level) {
    if (!kDebugMode) return '';
    switch (level) {
      case logger_pkg.Level.trace:
      case logger_pkg.Level.verbose: // ignore: deprecated_member_use
        return '🔍';
      case logger_pkg.Level.debug:
        return '🐛';
      case logger_pkg.Level.info:
        return 'ℹ️';
      case logger_pkg.Level.warning:
        return '⚠️';
      case logger_pkg.Level.error:
        return '❌';
      case logger_pkg.Level.fatal:
      case logger_pkg.Level.wtf: // ignore: deprecated_member_use
        return '💀';
      case logger_pkg.Level.all:
      case logger_pkg.Level.off:
      case logger_pkg.Level.nothing: // ignore: deprecated_member_use
        return '';
    }
  }

  String _getLevelName(logger_pkg.Level level) {
    return level.name.toUpperCase().padRight(5);
  }

  static const String _reset = '\x1B[0m';
}

/// Логгер для плагина hms_services.
///
/// Все методы логирования работают только в режиме отладки.
/// В release режиме логи не выводятся.
///
/// Пример использования:
/// ```dart
/// HmsLogger.debug('Начало настройки');
/// HmsLogger.info('Успешно добавлен плагин');
/// HmsLogger.warning('Файл уже содержит настройки');
/// HmsLogger.error('Ошибка при чтении файла', error: e, stackTrace: s);
/// ```
class HmsLogger {
  HmsLogger._();

  /// Выводит отладочное сообщение.
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (error != null) {
        _logger.d(message, error: error, stackTrace: stackTrace);
      } else {
        _logger.d(message);
      }
    }
  }

  /// Выводит информационное сообщение.
  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (error != null) {
        _logger.i(message, error: error, stackTrace: stackTrace);
      } else {
        _logger.i(message);
      }
    }
  }

  /// Выводит предупреждение.
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (error != null) {
        _logger.w(message, error: error, stackTrace: stackTrace);
      } else {
        _logger.w(message);
      }
    }
  }

  /// Выводит сообщение об ошибке.
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Выводит критическую ошибку.
  static void fatal(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.f(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Выводит трассировочное сообщение (самый детальный уровень).
  static void trace(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (error != null) {
        _logger.t(message, error: error, stackTrace: stackTrace);
      } else {
        _logger.t(message);
      }
    }
  }
}
