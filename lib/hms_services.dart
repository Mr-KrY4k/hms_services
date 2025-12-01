/// Публичный API для плагина hms_services.
///
/// Экспортирует основные модули для работы с Huawei Mobile Services.
library;

import 'adapters/ads/ads.dart';
import 'adapters/messaging/messaging.dart';
import 'src/logger.dart';

export 'src/hms_services_setup.dart' show setupHmsServices;
export 'src/hms_services_cleanup.dart' show cleanupHmsServices;
export 'src/setup_helper.dart' show SetupResult;
export 'adapters/ads/ads.dart' show Ads;
export 'adapters/messaging/messaging.dart'
    show Messaging, OnPushBlockedCallback;
export 'adapters/messaging/storage_keys.dart' show MessagingStorageKeys;
export 'consts.dart' show Consts;

/// Результат инициализации HMS сервисов.
class HmsServicesInitResult {
  /// Создает результат инициализации.
  HmsServicesInitResult({
    required this.success,
    required this.ads,
    required this.messaging,
    this.errors,
  });

  /// Общий успех инициализации (все сервисы инициализированы).
  final bool success;

  /// Результат инициализации Ads.
  final bool ads;

  /// Результат инициализации Messaging.
  final bool messaging;

  /// Список ошибок, если они были.
  final List<String>? errors;

  /// Получает список всех ошибок.
  List<String> get allErrors {
    final errorsList = <String>[];
    if (errors != null) {
      errorsList.addAll(errors!);
    }
    return errorsList;
  }
}

/// Главный сервис для работы с Huawei Mobile Services.
///
/// Предоставляет единую точку входа для инициализации всех адаптеров:
/// Ads, Messaging и других сервисов в будущем.
///
/// Пример использования:
/// ```dart
/// final result = await HmsServices.instance.init();
/// if (result.success) {
///   print('Все сервисы инициализированы');
/// } else {
///   print('Ошибки: ${result.allErrors}');
/// }
/// ```
final class HmsServices {
  HmsServices._();

  /// Единственный экземпляр класса.
  static final HmsServices instance = HmsServices._();

  /// Флаг инициализации.
  bool _isInitialized = false;

  /// Флаг выполнения инициализации.
  bool _isPending = false;

  /// Инициализирует все HMS сервисы.
  ///
  /// Инициализирует Messaging и другие сервисы.
  /// Метод безопасен для повторного вызова - повторная инициализация
  /// будет пропущена, если уже выполняется или завершена.
  ///
  /// [onPushBlocked] - опциональный колбек для обработки блокировки пушей.
  ///
  /// Возвращает [HmsServicesInitResult] с результатами инициализации каждого сервиса.
  Future<HmsServicesInitResult> init({void Function()? onPushBlocked}) async {
    if (_isInitialized) {
      HmsLogger.debug('HmsServices: уже инициализирован');
      return _createResult(
        ads: Ads.instance.isInitialized,
        messaging: Messaging.instance.isInitialized,
      );
    }

    if (_isPending) {
      HmsLogger.debug('HmsServices: инициализация уже выполняется');
      // Ждем завершения текущей инициализации
      while (_isPending) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _createResult(
        ads: Ads.instance.isInitialized,
        messaging: Messaging.instance.isInitialized,
      );
    }

    try {
      _isPending = true;
      HmsLogger.debug('HmsServices: начало инициализации');

      // Устанавливаем колбек для Messaging, если передан
      if (onPushBlocked != null) {
        Messaging.instance.setOnPushBlockedCallback(onPushBlocked);
      }

      final errors = <String>[];
      bool adsSuccess = false;
      bool messagingSuccess = false;

      // Инициализация Ads
      try {
        await Ads.instance.init();
        adsSuccess = true;
        HmsLogger.debug('HmsServices: Ads инициализирован');
      } catch (e, st) {
        errors.add('Ads: $e');
        HmsLogger.error(
          'HmsServices: ошибка при инициализации Ads',
          error: e,
          stackTrace: st,
        );
      }

      // Инициализация Messaging
      try {
        await Messaging.instance.init();
        messagingSuccess = true;
        HmsLogger.debug('HmsServices: Messaging инициализирован');
      } catch (e, st) {
        errors.add('Messaging: $e');
        HmsLogger.error(
          'HmsServices: ошибка при инициализации Messaging',
          error: e,
          stackTrace: st,
        );
      }

      final success = adsSuccess && messagingSuccess;
      _isInitialized = success;

      final result = HmsServicesInitResult(
        success: success,
        ads: adsSuccess,
        messaging: messagingSuccess,
        errors: errors.isEmpty ? null : errors,
      );

      if (success) {
        HmsLogger.debug('HmsServices: все сервисы успешно инициализированы');
      } else {
        HmsLogger.warning(
          'HmsServices: инициализация завершена с ошибками: ${errors.length}',
        );
      }

      return result;
    } finally {
      _isPending = false;
    }
  }

  /// Создает результат инициализации на основе текущего состояния.
  HmsServicesInitResult _createResult({
    required bool ads,
    required bool messaging,
  }) {
    return HmsServicesInitResult(
      success: ads && messaging,
      ads: ads,
      messaging: messaging,
    );
  }

  /// Проверяет, инициализированы ли все сервисы.
  bool get isInitialized => _isInitialized;

  /// Проверяет, выполняется ли инициализация.
  bool get isPending => _isPending;

  /// Получает экземпляр Ads.
  Ads get ads => Ads.instance;

  /// Получает экземпляр Messaging.
  Messaging get messaging => Messaging.instance;
}
