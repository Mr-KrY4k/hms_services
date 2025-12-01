import 'dart:async';

import 'package:huawei_ads/huawei_ads.dart';

import '../../consts.dart';
import '../../src/logger.dart';

/// Адаптер для работы с Huawei Ads.
///
/// Предоставляет упрощенный интерфейс для получения рекламного ID.
///
/// Пример использования:
/// ```dart
/// await Ads.instance.init();
/// final advertisingId = await Ads.instance.advertisingId;
/// ```
final class Ads {
  Ads._();

  /// Единственный экземпляр класса.
  static final Ads instance = Ads._();

  /// Completer для получения рекламного ID.
  final _advertisingIdCompleter = Completer<String>();

  /// Флаг инициализации.
  bool _isInitialized = false;

  /// Флаг выполнения инициализации.
  bool _isPending = false;

  /// Получает рекламный ID.
  ///
  /// Возвращает рекламный ID после завершения инициализации.
  Future<String> get advertisingId => _advertisingIdCompleter.future;

  /// Инициализирует Ads.
  ///
  /// Получает рекламный ID через AdvertisingIdClient.
  /// Метод безопасен для повторного вызова - повторная инициализация
  /// будет пропущена, если уже выполняется или завершена.
  ///
  /// Выбрасывает исключение, если инициализация не удалась.
  Future<void> init() async {
    if (_isInitialized) {
      HmsLogger.debug('Ads: уже инициализирован');
      return;
    }

    if (_isPending) {
      HmsLogger.debug('Ads: инициализация уже выполняется');
      return;
    }

    try {
      _isPending = true;
      HmsLogger.debug('Ads: начало инициализации');

      await _getAdvertisingId();

      _isInitialized = true;
      HmsLogger.debug('Ads: успешно инициализирован');
    } catch (e, st) {
      _isInitialized = false;
      HmsLogger.error(
        'Ads: ошибка при инициализации',
        error: e,
        stackTrace: st,
      );
      if (!_advertisingIdCompleter.isCompleted) {
        _advertisingIdCompleter.complete(Consts.notAvailable);
      }
      rethrow;
    } finally {
      _isPending = false;
    }
  }

  /// Получает рекламный ID.
  Future<void> _getAdvertisingId() async {
    try {
      final client = await AdvertisingIdClient.getAdvertisingIdInfo();
      final id = client.getId ?? Consts.notAvailable;

      HmsLogger.debug('Ads: рекламный ID получен: $id');
      _advertisingIdCompleter.complete(id);
    } catch (e, st) {
      HmsLogger.error(
        'Ads: ошибка при получении рекламного ID',
        error: e,
        stackTrace: st,
      );
      if (!_advertisingIdCompleter.isCompleted) {
        _advertisingIdCompleter.complete(Consts.notAvailable);
      }
      rethrow;
    }
  }

  /// Проверяет, инициализирован ли Ads.
  bool get isInitialized => _isInitialized;

  /// Проверяет, выполняется ли инициализация.
  bool get isPending => _isPending;
}
