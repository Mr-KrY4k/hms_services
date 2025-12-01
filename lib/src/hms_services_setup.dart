/// Модуль для настройки Android проекта для плагина hms_services.
library hms_services_setup;

import 'dart:io';
import 'setup_helper.dart' as helper;

/// Результат выполнения операции настройки/очистки.
typedef SetupResult = helper.SetupResult;

/// Настраивает Android проект для использования плагина hms_services.
///
/// Эта функция автоматически добавляет необходимые плагины Huawei Services,
/// зависимости и настройки в файлы проекта.
///
/// [projectRoot] - опциональный путь к корневой директории Flutter проекта.
/// Если не указан, будет использоваться автоматический поиск.
///
/// Возвращает [SetupResult] с информацией о выполненных изменениях.
///
/// Пример использования:
/// ```dart
/// import 'package:hms_services/src/hms_services_setup.dart';
///
/// final result = await setupHmsServices();
/// if (result.changesMade) {
///   print('Настройка завершена');
///   for (final message in result.messages) {
///     print(message);
///   }
/// }
/// ```
Future<SetupResult> setupHmsServices({String? projectRoot}) async {
  final messages = <String>[];
  bool changesMade = false;

  // Определяем корневую директорию проекта
  final root = projectRoot != null
      ? Directory(projectRoot)
      : helper.findProjectRoot();
  if (root == null) {
    return SetupResult(
      changesMade: false,
      messages: [
        '❌ Ошибка: Не найдена корневая директория Flutter проекта.',
        '   Убедитесь, что вы запускаете скрипт из корня проекта.',
      ],
    );
  }

  final androidDir = Directory('${root.path}/android');
  if (!androidDir.existsSync()) {
    return SetupResult(
      changesMade: false,
      messages: ['❌ Ошибка: Директория android не найдена.'],
    );
  }

  // Настройка settings.gradle.kts
  final settingsFile = File('${androidDir.path}/settings.gradle.kts');
  if (settingsFile.existsSync()) {
    messages.add('📝 Обновление settings.gradle.kts...');
    if (helper.updateSettingsGradle(settingsFile)) {
      changesMade = true;
      messages.add('✅ settings.gradle.kts обновлен успешно.');
    } else {
      messages.add(
        'ℹ️  settings.gradle.kts уже содержит необходимые настройки.',
      );
    }
  } else {
    messages.add('⚠️  Файл settings.gradle.kts не найден. Пропуск...');
  }

  // Настройка AndroidManifest.xml
  final manifestFile = File(
    '${androidDir.path}/app/src/main/AndroidManifest.xml',
  );
  if (manifestFile.existsSync()) {
    messages.add('📝 Обновление AndroidManifest.xml...');
    if (helper.updateAndroidManifest(manifestFile)) {
      changesMade = true;
      messages.add('✅ AndroidManifest.xml обновлен успешно.');
    } else {
      messages.add(
        'ℹ️  AndroidManifest.xml уже содержит необходимые настройки.',
      );
    }
  } else {
    messages.add('⚠️  Файл AndroidManifest.xml не найден. Пропуск...');
  }

  // Добавляем финальные сообщения для пользователя
  if (changesMade) {
    messages.add('');
    messages.add('✅ Настройка завершена! Не забудьте:');
    messages.add('   1. Выполнить flutter pub get');
    messages.add('   2. Пересобрать проект');
  } else {
    messages.add('');
    messages.add('✅ Проект уже настроен правильно!');
  }

  return SetupResult(changesMade: changesMade, messages: messages);
}

