/// Модуль для удаления настроек Android проекта для плагина hms_services.
library;

import 'dart:io';
import 'setup_helper.dart' as helper;

/// Результат выполнения операции настройки/очистки.
typedef SetupResult = helper.SetupResult;

/// Удаляет настройки Android проекта для плагина hms_services.
///
/// Эта функция автоматически удаляет плагины Huawei Services,
/// зависимости и настройки из файлов проекта.
///
/// [projectRoot] - опциональный путь к корневой директории Flutter проекта.
/// Если не указан, будет использоваться автоматический поиск.
///
/// Возвращает [SetupResult] с информацией о выполненных изменениях.
///
/// Пример использования:
/// ```dart
/// import 'package:hms_services/src/hms_services_cleanup.dart';
///
/// final result = await cleanupHmsServices();
/// if (result.changesMade) {
///   print('Очистка завершена');
///   for (final message in result.messages) {
///     print(message);
///   }
/// }
/// ```
Future<SetupResult> cleanupHmsServices({String? projectRoot}) async {
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

  // Удаление из settings.gradle (поддерживает .kts и .gradle)
  final settingsFile = helper.findSettingsGradleFile(androidDir);
  if (settingsFile != null) {
    final fileName = settingsFile.path.split('/').last;
    messages.add('📝 Обновление $fileName...');
    if (helper.removeFromSettingsGradle(settingsFile)) {
      changesMade = true;
      messages.add('✅ Плагины удалены из $fileName.');
    } else {
      messages.add('ℹ️  Плагины не найдены в $fileName.');
    }
  } else {
    messages.add('⚠️  Файл settings.gradle(.kts) не найден. Пропуск...');
  }

  // Удаление из build.gradle (поддерживает .kts и .gradle)
  final buildGradleFile = helper.findBuildGradleFile(androidDir);
  if (buildGradleFile != null) {
    final fileName = buildGradleFile.path.split('/').last;
    messages.add('📝 Обновление $fileName...');
    if (helper.removeFromBuildGradle(buildGradleFile)) {
      changesMade = true;
      messages.add('✅ Настройки удалены из $fileName.');
    } else {
      messages.add('ℹ️  Настройки не найдены в $fileName.');
    }
  } else {
    messages.add('⚠️  Файл build.gradle(.kts) не найден. Пропуск...');
  }

  // Удаление из AndroidManifest.xml
  final manifestFile = File(
    '${androidDir.path}/app/src/main/AndroidManifest.xml',
  );
  if (manifestFile.existsSync()) {
    messages.add('📝 Обновление AndroidManifest.xml...');
    if (helper.removeFromAndroidManifest(manifestFile)) {
      changesMade = true;
      messages.add('✅ Настройки удалены из AndroidManifest.xml.');
    } else {
      messages.add('ℹ️  Настройки не найдены в AndroidManifest.xml.');
    }
  } else {
    messages.add('⚠️  Файл AndroidManifest.xml не найден. Пропуск...');
  }

  // Удаление из proguard-rules.pro
  final proguardFile = File('${androidDir.path}/app/proguard-rules.pro');
  if (proguardFile.existsSync()) {
    messages.add('📝 Обновление proguard-rules.pro...');
    if (helper.removeFromProguardRules(proguardFile)) {
      changesMade = true;
      if (proguardFile.existsSync()) {
        messages.add('✅ Настройки удалены из proguard-rules.pro.');
      } else {
        messages.add('✅ Файл proguard-rules.pro удален (стал пустым).');
      }
    } else {
      messages.add('ℹ️  Настройки не найдены в proguard-rules.pro.');
    }
  } else {
    messages.add('ℹ️  Файл proguard-rules.pro не найден. Пропуск...');
  }

  final shouldRemoveDebugOptimizations = !proguardFile.existsSync();

  // Удаление из app/build.gradle (поддерживает .kts и .gradle)
  final appBuildGradleFile = helper.findAppBuildGradleFile(androidDir);
  if (appBuildGradleFile != null) {
    final fileName = appBuildGradleFile.path.split('/').last;
    messages.add('📝 Обновление $fileName...');
    if (helper.removeFromAppBuildGradle(
      appBuildGradleFile,
      removeDebugOptimizations: shouldRemoveDebugOptimizations,
    )) {
      changesMade = true;
      messages.add('✅ Настройки удалены из $fileName.');
    } else {
      messages.add('ℹ️  Настройки не найдены в $fileName.');
    }
  } else {
    messages.add('⚠️  Файл app/build.gradle(.kts) не найден. Пропуск...');
  }

  // Добавляем финальное сообщение
  messages.add('');
  if (changesMade) {
    messages.add('✅ Удаление настроек завершено!');
  } else {
    messages.add('✅ Настройки уже удалены или не найдены!');
  }

  return SetupResult(changesMade: changesMade, messages: messages);
}

