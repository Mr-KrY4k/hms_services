/// Внутренний модуль с общей логикой для настройки и очистки Android проекта.
library hms_services_setup_helper;

import 'dart:io';

/// Результат выполнения операции настройки/очистки.
class SetupResult {
  /// Были ли внесены изменения в файлы.
  final bool changesMade;

  /// Сообщения о выполненных операциях.
  final List<String> messages;

  SetupResult({required this.changesMade, required this.messages});
}

/// Константы для плагинов и настроек HMS
const String agconnectPlugin =
    'id("com.huawei.agconnect") version "1.9.1.303" apply false';

/// XML для intent в queries для com.huawei.hms.core.aidlservice
const String hmsAidlServiceIntent = '''
        <intent>
            <action android:name="com.huawei.hms.core.aidlservice" />
        </intent>''';

/// XML для meta-data push_kit_auto_init_enabled
const String pushKitAutoInitMetaData =
    '<meta-data android:name="push_kit_auto_init_enabled" android:value="true" />';

/// XML для receiver HmsLocalNotificationBootEventReceiver
const String hmsLocalNotificationBootEventReceiver = '''
        <receiver android:name="com.huawei.hms.flutter.push.receiver.local.HmsLocalNotificationBootEventReceiver" android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>''';

/// XML для receiver HmsLocalNotificationScheduledPublisher
const String hmsLocalNotificationScheduledPublisher =
    '<receiver android:name="com.huawei.hms.flutter.push.receiver.local.HmsLocalNotificationScheduledPublisher" android:exported="false" />';

/// XML для receiver BackgroundMessageBroadcastReceiver
const String backgroundMessageBroadcastReceiver = '''
        <receiver android:name="com.huawei.hms.flutter.push.receiver.BackgroundMessageBroadcastReceiver" android:exported="false">
            <intent-filter>
                <action android:name="com.huawei.hms.flutter.push.receiver.BACKGROUND_REMOTE_MESSAGE" />
            </intent-filter>
        </receiver>''';

/// Находит корневую директорию Flutter проекта
Directory? findProjectRoot([String? startPath]) {
  Directory current = startPath != null
      ? Directory(startPath)
      : Directory.current;
  while (current.path != current.parent.path) {
    final pubspecFile = File('${current.path}/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      return current;
    }
    current = current.parent;
  }
  return null;
}

/// Обновляет settings.gradle.kts, добавляя плагин Huawei AGConnect
bool updateSettingsGradle(File file) {
  final content = file.readAsStringSync();

  // Проверяем, есть ли уже плагин
  if (content.contains('com.huawei.agconnect')) {
    return false; // Уже настроено
  }

  // Ищем блок plugins (многострочный)
  final pluginsBlockRegex = RegExp(
    r'plugins\s*\{[^}]*\}',
    multiLine: true,
    dotAll: true,
  );

  final match = pluginsBlockRegex.firstMatch(content);
  if (match != null) {
    final pluginsBlock = match.group(0)!;

    // Проверяем, есть ли уже нужный плагин в блоке
    if (pluginsBlock.contains('com.huawei.agconnect')) {
      return false;
    }

    // Добавляем плагин перед закрывающей скобкой блока
    final updatedPluginsBlock = pluginsBlock.replaceFirst(
      '}',
      '    // Плагин для hms_services:\n    $agconnectPlugin\n}',
    );

    final newContent = content.replaceFirst(pluginsBlock, updatedPluginsBlock);
    file.writeAsStringSync(newContent);
    return true;
  } else {
    // Если блока plugins нет, добавляем после pluginManagement
    final pluginManagementEnd = content.indexOf('include(');
    if (pluginManagementEnd == -1) {
      // Если нет include, добавляем в конец
      final newContent =
          '$content\n\nplugins {\n    // Плагин для hms_services:\n    $agconnectPlugin\n}\n';
      file.writeAsStringSync(newContent);
      return true;
    } else {
      // Вставляем перед include
      final before = content.substring(0, pluginManagementEnd);
      final after = content.substring(pluginManagementEnd);
      final newContent =
          '$before\nplugins {\n    // Плагин для hms_services:\n    $agconnectPlugin\n}\n\n$after';
      file.writeAsStringSync(newContent);
      return true;
    }
  }
}

/// Обновляет AndroidManifest.xml, добавляя настройки HMS
bool updateAndroidManifest(File file) {
  final lines = file.readAsLinesSync();

  // Проверяем, есть ли уже настройки HMS
  // Проверяем наличие intent в queries
  final hasAidlIntent = lines.any(
    (line) => line.contains('com.huawei.hms.core.aidlservice'),
  );
  final hasPushKitMeta = lines.any(
    (line) => line.contains('push_kit_auto_init_enabled'),
  );
  final hasBootReceiver = lines.any(
    (line) => line.contains('HmsLocalNotificationBootEventReceiver'),
  );
  final hasScheduledReceiver = lines.any(
    (line) => line.contains('HmsLocalNotificationScheduledPublisher'),
  );
  final hasBackgroundReceiver = lines.any(
    (line) => line.contains('BackgroundMessageBroadcastReceiver'),
  );

  final hasHmsSettings =
      hasAidlIntent &&
      hasPushKitMeta &&
      hasBootReceiver &&
      hasScheduledReceiver &&
      hasBackgroundReceiver;

  if (hasHmsSettings) {
    return false; // Уже добавлено
  }

  // Ищем тег <application> или создаем его
  int applicationCloseIndex = -1;
  bool hasApplicationTag = false;

  // Ищем тег <queries> для добавления intent
  int queriesCloseIndex = -1;
  bool hasQueriesTag = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.startsWith('<application')) {
      hasApplicationTag = true;
    }
    if (hasApplicationTag && line == '</application>') {
      applicationCloseIndex = i;
    }
    if (line == '<queries>') {
      hasQueriesTag = true;
    }
    if (hasQueriesTag && line == '</queries>') {
      queriesCloseIndex = i;
      break;
    }
  }

  final newLines = <String>[];

  if (!hasApplicationTag) {
    // Если нет тега application, создаем его
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim() == '</manifest>') {
        // Вставляем application перед </manifest>
        newLines.add('    <application>');
        newLines.add('        $pushKitAutoInitMetaData');
        newLines.add('');
        newLines.add(hmsLocalNotificationBootEventReceiver);
        newLines.add('');
        newLines.add('        $hmsLocalNotificationScheduledPublisher');
        newLines.add('');
        newLines.add(backgroundMessageBroadcastReceiver);
        newLines.add('    </application>');
        newLines.add(line);
      } else {
        newLines.add(line);
      }
    }
  } else {
    // Если тег application есть, добавляем настройки перед закрывающим тегом
    for (int i = 0; i < lines.length; i++) {
      if (i == applicationCloseIndex) {
        // Вставляем перед закрывающим тегом application
        newLines.add('        $pushKitAutoInitMetaData');
        newLines.add('');
        newLines.add(hmsLocalNotificationBootEventReceiver);
        newLines.add('');
        newLines.add('        $hmsLocalNotificationScheduledPublisher');
        newLines.add('');
        newLines.add(backgroundMessageBroadcastReceiver);
        newLines.add(lines[i]);
      } else {
        newLines.add(lines[i]);
      }
    }
  }

  // Добавляем intent в queries
  // Пересчитываем индексы queries в newLines
  int newQueriesCloseIndex = -1;
  bool newHasQueriesTag = false;

  for (int i = 0; i < newLines.length; i++) {
    final line = newLines[i].trim();
    if (line == '<queries>') {
      newHasQueriesTag = true;
    }
    if (newHasQueriesTag && line == '</queries>') {
      newQueriesCloseIndex = i;
      break;
    }
  }

  if (newHasQueriesTag && newQueriesCloseIndex != -1) {
    // Если queries существует, добавляем intent перед закрывающим тегом
    final updatedLines = <String>[];
    for (int i = 0; i < newLines.length; i++) {
      if (i == newQueriesCloseIndex) {
        updatedLines.add(hmsAidlServiceIntent);
        updatedLines.add(newLines[i]);
      } else {
        updatedLines.add(newLines[i]);
      }
    }
    newLines.clear();
    newLines.addAll(updatedLines);
  } else {
    // Если queries нет, создаем его перед </manifest>
    final updatedLines = <String>[];
    for (int i = 0; i < newLines.length; i++) {
      final line = newLines[i];
      if (line.trim() == '</manifest>') {
        updatedLines.add('    <queries>');
        updatedLines.add(hmsAidlServiceIntent);
        updatedLines.add('    </queries>');
        updatedLines.add(line);
      } else {
        updatedLines.add(line);
      }
    }
    newLines.clear();
    newLines.addAll(updatedLines);
  }

  file.writeAsStringSync(newLines.join('\n') + '\n');
  return true;
}

/// Удаляет настройки из settings.gradle.kts
bool removeFromSettingsGradle(File file) {
  final lines = file.readAsLinesSync();

  // Проверяем, есть ли плагин
  final hasPlugin = lines.any((line) => line.contains('com.huawei.agconnect'));

  if (!hasPlugin) {
    return false; // Нечего удалять
  }

  final newLines = <String>[];
  bool foundComment = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Пропускаем комментарий
    if (trimmed.contains('// Плагин для hms_services:') ||
        trimmed.contains('//Плагин для hms_services:')) {
      foundComment = true;
      continue;
    }

    // Пропускаем строки с плагином
    if (trimmed.contains('com.huawei.agconnect') &&
        (trimmed.contains('apply false') || trimmed.contains('version'))) {
      continue;
    }

    newLines.add(line);
  }

  // Удаляем лишние пустые строки в конце
  while (newLines.isNotEmpty && newLines.last.trim().isEmpty) {
    newLines.removeLast();
  }

  if (newLines.length != lines.length || foundComment) {
    file.writeAsStringSync(newLines.join('\n') + '\n');
    return true;
  }

  return false;
}

/// Удаляет настройки из AndroidManifest.xml
bool removeFromAndroidManifest(File file) {
  final lines = file.readAsLinesSync();

  // Проверяем, есть ли настройки HMS
  final hasHmsSettings = lines.any(
    (line) =>
        line.contains('com.huawei.hms.core.aidlservice') ||
        line.contains('push_kit_auto_init_enabled') ||
        line.contains('HmsLocalNotificationBootEventReceiver') ||
        line.contains('HmsLocalNotificationScheduledPublisher') ||
        line.contains('BackgroundMessageBroadcastReceiver'),
  );

  if (!hasHmsSettings) {
    return false; // Нечего удалять
  }

  final newLines = <String>[];
  bool found = false;
  bool skipNextLines = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Если мы в режиме пропуска строк (skipNextLines), проверяем закрывающие теги
    if (skipNextLines) {
      // КРИТИЧНО: Не пропускаем закрывающий тег </application>
      // Это защита от случайного удаления структуры манифеста
      if (trimmed == '</application>') {
        newLines.add(line);
        skipNextLines = false;
        continue;
      }
      // Останавливаем пропуск при закрытии текущего элемента
      if (trimmed.contains('</intent>') || trimmed.contains('</receiver>')) {
        skipNextLines = false;
      }
      continue; // Пропускаем все строки внутри удаляемого элемента
    }

    // 1. Удаление intent с com.huawei.hms.core.aidlservice в блоке <queries>
    if (trimmed.contains('<intent>')) {
      // Проверяем следующие строки до </intent> на наличие нашего action
      bool isOurIntent = false;
      for (int j = i; j < i + 5 && j < lines.length; j++) {
        if (lines[j].contains('com.huawei.hms.core.aidlservice')) {
          isOurIntent = true;
          break;
        }
        if (lines[j].trim().contains('</intent>')) {
          break;
        }
      }
      if (isOurIntent) {
        found = true;
        skipNextLines = true; // Пропускаем весь блок <intent>...</intent>
        continue;
      }
    }

    // 2. Удаление meta-data для push_kit_auto_init_enabled
    // Это однострочный элемент, просто пропускаем его
    if (trimmed.contains('push_kit_auto_init_enabled')) {
      found = true;
      continue; // Не добавляем эту строку в newLines
    }

    // 3. Удаление receiver HmsLocalNotificationBootEventReceiver
    // Это многострочный элемент <receiver>...</receiver>
    if (trimmed.contains('HmsLocalNotificationBootEventReceiver')) {
      found = true;
      skipNextLines = true; // Пропускаем весь блок <receiver>...</receiver>
      continue;
    }

    // 4. Удаление receiver HmsLocalNotificationScheduledPublisher
    if (trimmed.contains('HmsLocalNotificationScheduledPublisher')) {
      found = true;
      skipNextLines = true;
      continue;
    }

    // 5. Удаление receiver BackgroundMessageBroadcastReceiver
    if (trimmed.contains('BackgroundMessageBroadcastReceiver')) {
      found = true;
      skipNextLines = true;
      continue;
    }

    // Если строка не является удаляемым элементом, добавляем её в результат
    newLines.add(line);
  }

  if (found) {
    file.writeAsStringSync(newLines.join('\n') + '\n');
    return true;
  }

  return false;
}
