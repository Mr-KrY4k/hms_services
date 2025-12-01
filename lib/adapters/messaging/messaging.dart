import 'dart:async';

import 'package:huawei_push/huawei_push.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../consts.dart';
import '../../src/logger.dart';
import '../../src/storage/storage.dart';
import 'storage_keys.dart';

/// Колбек для обработки события блокировки пушей.
typedef OnPushBlockedCallback = void Function();

/// Адаптер для работы с Huawei Push Messaging.
///
/// Предоставляет упрощенный интерфейс для работы с push-уведомлениями,
/// включая инициализацию, обработку входящих сообщений и их хранение.
///
/// Пример использования:
/// ```dart
/// Messaging.instance.setOnPushBlockedCallback(() {
///   // Обработка блокировки пушей
/// });
/// await Messaging.instance.init();
/// final token = await Messaging.instance.token;
/// ```
final class Messaging {
  Messaging._();

  /// Единственный экземпляр класса.
  static final Messaging instance = Messaging._();

  /// Storage для хранения сообщений.
  late final Storage _storage = Storage(MessagingStorageKeys.pushMessagesBox);

  /// Колбек для обработки блокировки пушей.
  OnPushBlockedCallback? _onPushBlockedCallback;

  /// Completer для получения токена.
  final _tokenCompleter = Completer<String>();

  /// Стрим контроллер для входящих сообщений.
  final _onMessageReceived =
      StreamController<Map<Object?, Object?>>.broadcast();

  /// Стрим контроллер для изменения статуса уведомлений.
  final _onNotificationStatusChanged = StreamController<bool>.broadcast();

  /// Список всех полученных сообщений.
  final List<Map<Object?, Object?>> _messages = [];

  /// Флаг инициализации.
  bool _isInitialized = false;

  /// Флаг выполнения инициализации.
  bool _isPending = false;

  /// Подписка на стрим токенов.
  StreamSubscription<String>? _tokenSubscription;

  /// Получает токен.
  ///
  /// Возвращает токен после завершения инициализации.
  Future<String> get token => _tokenCompleter.future;

  /// Получает список всех сообщений.
  List<Map<Object?, Object?>> get messages => List.unmodifiable(_messages);

  /// Стрим входящих сообщений.
  Stream<Map<Object?, Object?>> get onMessageReceived =>
      _onMessageReceived.stream;

  /// Стрим изменения статуса уведомлений.
  Stream<bool> get onNotificationStatusChanged =>
      _onNotificationStatusChanged.stream;

  /// Устанавливает колбек для обработки блокировки пушей.
  ///
  /// [callback] - функция, которая будет вызвана при блокировке пушей.
  void setOnPushBlockedCallback(OnPushBlockedCallback? callback) {
    _onPushBlockedCallback = callback;
  }

  /// Инициализирует Messaging.
  ///
  /// Запрашивает разрешения, настраивает слушатели сообщений,
  /// загружает сохраненные сообщения и получает токен.
  /// Метод безопасен для повторного вызова - повторная инициализация
  /// будет пропущена, если уже выполняется или завершена.
  ///
  /// Выбрасывает исключение, если инициализация не удалась.
  Future<void> init() async {
    if (_isInitialized) {
      HmsLogger.debug('Messaging: уже инициализирован');
      return;
    }

    if (_isPending) {
      HmsLogger.debug('Messaging: инициализация уже выполняется');
      return;
    }

    try {
      _isPending = true;
      HmsLogger.debug('Messaging: начало инициализации');

      await _storage.init();
      await _requestPermission();

      // Проверяем, был ли это первый запрос разрешения
      final firstRequest = _storage.get(
        MessagingStorageKeys.firstPushRequestPermission,
      );
      if (firstRequest == null) {
        await _storage.save(MessagingStorageKeys.firstPushRequestPermission, {
          'value': false,
        });
      } else {
        // Если это не первый запрос, проверяем статус и вызываем колбек при блокировке
        final status = await Permission.notification.status;
        if (status == PermissionStatus.denied) {
          _onPushBlockedCallback?.call();
        }
      }

      await _loadStoredMessages();
      await _checkNotificationStatus();
      await _getToken();
      await _handleInitialMessage();
      await _setupMessageListeners();

      _isInitialized = true;
      HmsLogger.debug('Messaging: успешно инициализирован');
    } catch (e, st) {
      _isInitialized = false;
      HmsLogger.error(
        'Messaging: ошибка при инициализации',
        error: e,
        stackTrace: st,
      );
      if (!_tokenCompleter.isCompleted) {
        _tokenCompleter.complete(Consts.notAvailable);
      }
      rethrow;
    } finally {
      _isPending = false;
    }
  }

  /// Запрашивает разрешение на уведомления.
  Future<void> _requestPermission() async {
    try {
      await Permission.notification.request();
      HmsLogger.debug('Messaging: разрешение запрошено');
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при запросе разрешения',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Загружает сохраненные сообщения из storage.
  Future<void> _loadStoredMessages() async {
    try {
      final allMessages = _storage.getAll();
      _messages.clear();

      for (final messageMap in allMessages) {
        try {
          // Преобразуем Map<String, dynamic> в Map<Object?, Object?>
          final message = Map<Object?, Object?>.from(messageMap);
          _messages.add(message);
        } catch (e, st) {
          HmsLogger.error(
            'Messaging: ошибка при загрузке сообщения из storage',
            error: e,
            stackTrace: st,
          );
        }
      }

      HmsLogger.debug('Messaging: загружено ${_messages.length} сообщений');
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при загрузке сохраненных сообщений',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Сохраняет входящее сообщение в storage.
  Future<void> _saveMessage(Map<Object?, Object?> message) async {
    try {
      final extras = message['extras'] as Map<Object?, Object?>?;
      final messageId =
          extras?['_push_msgid'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Преобразуем Map<Object?, Object?> в Map<String, dynamic> для storage
      final messageMap = <String, dynamic>{};
      for (final entry in message.entries) {
        final key = entry.key?.toString() ?? '';
        if (entry.value is Map) {
          final valueMap = <String, dynamic>{};
          for (final valueEntry in (entry.value as Map).entries) {
            valueMap[valueEntry.key?.toString() ?? ''] = valueEntry.value
                ?.toString();
          }
          messageMap[key] = valueMap;
        } else {
          messageMap[key] = entry.value?.toString();
        }
      }

      await _storage.save(messageId, messageMap);
      HmsLogger.debug('Messaging: сообщение сохранено: $messageId');
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при сохранении сообщения',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Обрабатывает входящее сообщение.
  Future<void> _handleIncomingMessage(Map<Object?, Object?> message) async {
    try {
      final extras = message['extras'] as Map<Object?, Object?>?;
      final messageId = extras?['_push_msgid'] as String?;
      HmsLogger.debug('Messaging: получено сообщение: $messageId');

      _onMessageReceived.add(message);
      _messages.add(message);
      await _saveMessage(message);
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при обработке входящего сообщения',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Обрабатывает входящее сообщение с открытием приложения.
  Future<void> _handleIncomingMessageWithOpen(
    Map<Object?, Object?> message,
  ) async {
    await _handleIncomingMessage(message);
    await _saveLastPushOpenMeta(message);
  }

  /// Обрабатывает начальное сообщение (когда приложение открыто из уведомления).
  Future<void> _handleInitialMessage() async {
    try {
      final message = await Push.getInitialNotification();
      if (message != null) {
        await _handleIncomingMessageWithOpen(message);
      }
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при обработке начального сообщения',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Настраивает слушатели сообщений.
  Future<void> _setupMessageListeners() async {
    try {
      // Huawei Push использует нативные обработчики через AndroidManifest.xml
      // Здесь можно добавить дополнительные слушатели, если API это поддерживает
      HmsLogger.debug('Messaging: слушатели сообщений настроены');
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при настройке слушателей',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Сохраняет метаданные последнего открытого пуша.
  Future<void> _saveLastPushOpenMeta(Map<Object?, Object?> message) async {
    try {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final extras = message['extras'] as Map<Object?, Object?>?;
      final messageId = extras?['_push_msgid'] as String? ?? 'unknown';

      await _storage.save(MessagingStorageKeys.lastPushOpenTime, {
        'timestamp': currentTime,
      });
      await _storage.save(MessagingStorageKeys.lastPushOpenMessageId, {
        'id': messageId,
      });
      await _storage.save(MessagingStorageKeys.lastPushOpenViewed, {
        'viewed': false,
      });

      HmsLogger.debug(
        'Messaging: сохранены метаданные последнего пуша: time=$currentTime, id=$messageId',
      );
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при сохранении метаданных последнего пуша',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Получает время последнего открытия пуша.
  Future<DateTime?> _getLastPushOpenTime() async {
    try {
      final data = _storage.get(MessagingStorageKeys.lastPushOpenTime);
      if (data != null && data['timestamp'] != null) {
        final timestamp = data['timestamp'] as int;
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        HmsLogger.debug('Messaging: время последнего открытия: $dateTime');
        return dateTime;
      }
      return null;
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при получении времени последнего открытия',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Получает ID последнего открытого сообщения.
  Future<String?> _getLastPushOpenMessageId() async {
    try {
      final data = _storage.get(MessagingStorageKeys.lastPushOpenMessageId);
      return data?['id'] as String?;
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при получении ID последнего сообщения',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Получает токен.
  Future<void> _getToken() async {
    try {
      // Запрашиваем токен
      Push.getToken('');

      // Подписываемся на стрим токенов
      _tokenSubscription = Push.getTokenStream.listen(
        (token) {
          HmsLogger.debug('Messaging: токен получен: $token');
          if (!_tokenCompleter.isCompleted) {
            _tokenCompleter.complete(token);
          }
        },
        onError: (error) {
          HmsLogger.error(
            'Messaging: ошибка при получении токена',
            error: error,
          );
          if (!_tokenCompleter.isCompleted) {
            _tokenCompleter.complete(Consts.notAvailable);
          }
        },
      );
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при настройке получения токена',
        error: e,
        stackTrace: st,
      );
      if (!_tokenCompleter.isCompleted) {
        _tokenCompleter.complete(Consts.notAvailable);
      }
    }
  }

  /// Проверяет статус уведомлений.
  Future<void> _checkNotificationStatus() async {
    try {
      final status = await Permission.notification.status;
      final isGranted = status == PermissionStatus.granted;
      _onNotificationStatusChanged.add(isGranted);

      HmsLogger.debug('Messaging: статус уведомлений: $status');
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при проверке статуса уведомлений',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Проверяет, было ли приложение открыто через пуш.
  Future<bool> wasAppOpenedByPush() async {
    final lastOpenTime = await _getLastPushOpenTime();
    return lastOpenTime != null;
  }

  /// Проверяет, просмотрен ли последний открытый пуш.
  Future<bool> isLastOpenedPushViewed() async {
    try {
      final data = _storage.get(MessagingStorageKeys.lastPushOpenViewed);
      return data?['viewed'] == true;
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при проверке статуса просмотра',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Отмечает последний открытый пуш как просмотренный.
  Future<void> markLastOpenedPushAsViewed() async {
    try {
      await _storage.save(MessagingStorageKeys.lastPushOpenViewed, {
        'viewed': true,
      });
      final messageId = await _getLastPushOpenMessageId();
      HmsLogger.debug(
        'Messaging: последний пуш отмечен как просмотренный: id=${messageId ?? 'unknown'}',
      );
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при отметке пуша как просмотренного',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Проверяет, было ли приложение открыто через пуш и просмотрен ли он.
  Future<bool> wasAppOpenedByPushAndViewed() async {
    final opened = await wasAppOpenedByPush();
    if (!opened) return false;
    return await isLastOpenedPushViewed();
  }

  /// Проверяет, находится ли последнее открытие пуша в пределах 24 часов.
  Future<bool> isWithin24HoursFromPushOpen() async {
    final lastOpenTime = await _getLastPushOpenTime();
    if (lastOpenTime == null) {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(lastOpenTime);
    final isWithin24Hours = difference.inHours < 24;

    HmsLogger.debug(
      'Messaging: последнее открытие: $lastOpenTime, сейчас: $now, разница: ${difference.inHours}ч, в пределах 24ч: $isWithin24Hours',
    );

    return isWithin24Hours;
  }

  /// Проверяет, находится ли последнее открытие пуша в пределах 24 часов и просмотрен ли он.
  Future<bool> isWithin24HoursFromPushOpenAndViewed() async {
    final within24 = await isWithin24HoursFromPushOpen();
    if (!within24) return false;
    return await isLastOpenedPushViewed();
  }

  /// Получает последний открытый пуш в пределах 24 часов.
  Future<Map<Object?, Object?>?> getLastOpenedPushWithin24Hours() async {
    final lastOpenTime = await _getLastPushOpenTime();
    if (lastOpenTime == null) return null;

    if (DateTime.now().difference(lastOpenTime) >= const Duration(hours: 24)) {
      return null;
    }

    final messageId = await _getLastPushOpenMessageId();
    if (messageId == null || messageId.isEmpty) return null;

    for (final message in _messages) {
      final extras = message['extras'] as Map<Object?, Object?>?;
      final msgId = extras?['_push_msgid'] as String?;
      if (msgId == messageId) {
        return message;
      }
    }

    try {
      final allMessages = _storage.getAll();
      for (final messageMap in allMessages) {
        try {
          final message = Map<Object?, Object?>.from(messageMap);
          final extras = message['extras'] as Map<Object?, Object?>?;
          final msgId = extras?['_push_msgid'] as String?;
          if (msgId == messageId) {
            return message;
          }
        } catch (e) {
          // Пропускаем некорректные сообщения
        }
      }
    } catch (e, st) {
      HmsLogger.error(
        'Messaging: ошибка при поиске последнего открытого пуша',
        error: e,
        stackTrace: st,
      );
    }

    return null;
  }

  /// Проверяет, инициализирован ли Messaging.
  bool get isInitialized => _isInitialized;

  /// Проверяет, выполняется ли инициализация.
  bool get isPending => _isPending;

  /// Освобождает ресурсы.
  void dispose() {
    _tokenSubscription?.cancel();
    _onMessageReceived.close();
    _onNotificationStatusChanged.close();
  }
}
