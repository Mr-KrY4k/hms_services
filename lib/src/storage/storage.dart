import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../logger.dart' show HmsLogger;

/// Универсальный storage для хранения данных.
///
/// Предоставляет методы для сохранения, получения и удаления
/// данных в локальном хранилище. Может использоваться для любых
/// типов данных, хранящихся в виде Map.
///
/// Пример использования:
/// ```dart
/// final storage = Storage('my_box');
/// await storage.init();
/// await storage.save('key1', {'title': 'Test'});
/// final data = storage.get('key1');
/// ```
final class Storage {
  /// Создает экземпляр storage с указанным именем бокса.
  ///
  /// [boxName] - имя бокса для хранения данных.
  Storage(this.boxName);

  /// Имя бокса для хранения данных.
  final String boxName;

  /// Экземпляр Hive бокса.
  Box<Map>? _box;

  /// Флаг инициализации.
  bool _isInitialized = false;

  /// Флаг выполнения инициализации.
  bool _isPending = false;

  /// Флаг, что Hive уже инициализирован.
  static bool _hiveInitialized = false;

  /// Гарантирует, что Hive инициализирован с корректным путем.
  ///
  /// Логика аналогична использованию в приложении:
  /// - на Android/iOS используется `getApplicationDocumentsDirectory()`
  /// - на других платформах используется `Directory.current.path`
  static Future<void> _ensureHiveInitialized() async {
    if (_hiveInitialized) return;

    try {
      String path;
      if (Platform.isAndroid || Platform.isIOS) {
        final appDocDir = await getApplicationDocumentsDirectory();
        path = appDocDir.path;
      } else {
        path = Directory.current.path;
      }

      if (path.isEmpty) {
        throw Exception('Hive path is empty');
      }

      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      Hive.init(path);

      _hiveInitialized = true;
      HmsLogger.debug('Storage: Hive инициализирован по пути: $path');
    } catch (e, st) {
      HmsLogger.error(
        'Storage: ошибка при инициализации Hive',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Инициализирует storage.
  ///
  /// Открывает бокс для хранения данных.
  /// Метод безопасен для повторного вызова - повторная инициализация
  /// будет пропущена, если уже выполняется или завершена.
  ///
  /// Выбрасывает исключение, если инициализация не удалась.
  Future<void> init() async {
    if (_isInitialized) {
      HmsLogger.debug('Storage[$boxName]: уже инициализирован');
      return;
    }

    if (_isPending) {
      HmsLogger.debug('Storage[$boxName]: инициализация уже выполняется');
      return;
    }

    try {
      _isPending = true;
      HmsLogger.debug('Storage[$boxName]: начало инициализации');

      await _ensureHiveInitialized();

      _box = await Hive.openBox<Map>(boxName);
      _isInitialized = true;

      final count = _box!.length;
      HmsLogger.debug('Storage[$boxName]: бокс открыт, записей: $count');
      HmsLogger.debug('Storage[$boxName]: успешно инициализирован');
    } catch (e, st) {
      _isInitialized = false;
      HmsLogger.error(
        'Storage[$boxName]: ошибка при инициализации',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      _isPending = false;
    }
  }

  /// Сохраняет данные.
  ///
  /// [key] - уникальный ключ для данных.
  /// [data] - данные в виде Map.
  ///
  /// Выбрасывает [StateError], если storage не инициализирован.
  Future<void> save(String key, Map<String, dynamic> data) async {
    _ensureInitialized();

    try {
      await _box!.put(key, data);
      HmsLogger.debug('Storage[$boxName]: данные сохранены: $key');
    } catch (e, st) {
      HmsLogger.error(
        'Storage[$boxName]: ошибка при сохранении данных',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Получает данные по ключу.
  ///
  /// [key] - ключ данных.
  ///
  /// Возвращает данные или `null`, если данные не найдены.
  ///
  /// Выбрасывает [StateError], если storage не инициализирован.
  Map<String, dynamic>? get(String key) {
    _ensureInitialized();

    try {
      final data = _box!.get(key);
      if (data != null) {
        HmsLogger.debug('Storage[$boxName]: данные получены: $key');
        return Map<String, dynamic>.from(data);
      }
      HmsLogger.debug('Storage[$boxName]: данные не найдены: $key');
      return null;
    } catch (e, st) {
      HmsLogger.error(
        'Storage[$boxName]: ошибка при получении данных',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Получает все данные.
  ///
  /// Возвращает список всех сохраненных данных.
  ///
  /// Выбрасывает [StateError], если storage не инициализирован.
  List<Map<String, dynamic>> getAll() {
    _ensureInitialized();

    try {
      final allData = _box!.values.toList();
      final result = allData
          .map((data) => Map<String, dynamic>.from(data))
          .toList();
      HmsLogger.debug('Storage[$boxName]: получено ${result.length} записей');
      return result;
    } catch (e, st) {
      HmsLogger.error(
        'Storage[$boxName]: ошибка при получении всех данных',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Получает все ключи.
  ///
  /// Возвращает список всех ключей сохраненных данных.
  ///
  /// Выбрасывает [StateError], если storage не инициализирован.
  List<String> getAllKeys() {
    _ensureInitialized();

    try {
      final keys = _box!.keys.map((key) => key.toString()).toList();
      HmsLogger.debug('Storage[$boxName]: получено ${keys.length} ключей');
      return keys;
    } catch (e, st) {
      HmsLogger.error(
        'Storage[$boxName]: ошибка при получении ключей',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Удаляет данные по ключу.
  ///
  /// [key] - ключ данных для удаления.
  ///
  /// Возвращает `true`, если данные были удалены, `false` если не найдены.
  ///
  /// Выбрасывает [StateError], если storage не инициализирован.
  Future<bool> delete(String key) async {
    _ensureInitialized();

    try {
      if (_box!.containsKey(key)) {
        await _box!.delete(key);
        HmsLogger.debug('Storage[$boxName]: данные удалены: $key');
        return true;
      }
      HmsLogger.debug(
        'Storage[$boxName]: данные не найдены для удаления: $key',
      );
      return false;
    } catch (e, st) {
      HmsLogger.error(
        'Storage[$boxName]: ошибка при удалении данных',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Удаляет все данные.
  ///
  /// Выбрасывает [StateError], если storage не инициализирован.
  Future<void> clear() async {
    _ensureInitialized();

    try {
      await _box!.clear();
      HmsLogger.debug('Storage[$boxName]: все данные удалены');
    } catch (e, st) {
      HmsLogger.error(
        'Storage[$boxName]: ошибка при очистке хранилища',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Получает количество сохраненных записей.
  ///
  /// Выбрасывает [StateError], если storage не инициализирован.
  int get count {
    _ensureInitialized();
    return _box!.length;
  }

  /// Проверяет, инициализирован ли storage.
  bool get isInitialized => _isInitialized;

  /// Проверяет, выполняется ли инициализация.
  bool get isPending => _isPending;

  /// Проверяет, что storage инициализирован.
  ///
  /// Выбрасывает [StateError], если инициализация не выполнена.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'Storage[$boxName] не инициализирован. Вызовите init() перед использованием.',
      );
    }
  }
}
