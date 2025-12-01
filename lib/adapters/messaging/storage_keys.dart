/// Ключи для хранения данных в Messaging адаптере.
///
/// Все ключи используют префикс `hms_services_messaging_` для минимизации
/// конфликтов с ключами других разработчиков.
final class MessagingStorageKeys {
  MessagingStorageKeys._();

  /// Префикс для всех ключей плагина.
  static const String _prefix = 'hms_services_messaging_';

  /// Имя бокса для хранения push-сообщений.
  static const String pushMessagesBox = '${_prefix}push_messages_box';

  /// Ключ для хранения флага первого запроса разрешения на уведомления.
  static const String firstPushRequestPermission =
      '${_prefix}first_push_request_permission';

  /// Ключ для хранения времени последнего открытия пуша.
  static const String lastPushOpenTime = '${_prefix}last_push_open_time';

  /// Ключ для хранения ID последнего открытого сообщения.
  static const String lastPushOpenMessageId =
      '${_prefix}last_push_open_message_id';

  /// Ключ для хранения флага просмотра последнего открытого пуша.
  static const String lastPushOpenViewed = '${_prefix}last_push_open_viewed';
}

