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

/// XML для service с intent для com.huawei.hms.core.aidlservice
const String hmsAidlService = '''
        <service android:name="com.huawei.hms.core.aidlservice.AIDLService" android:exported="true">
            <intent-filter>
                <action android:name="com.huawei.hms.core.aidlservice" />
            </intent-filter>
        </service>''';

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
  final hasHmsSettings = lines.any(
    (line) =>
        line.contains('com.huawei.hms.core.aidlservice') ||
        line.contains('push_kit_auto_init_enabled') ||
        line.contains('HmsLocalNotificationBootEventReceiver') ||
        line.contains('HmsLocalNotificationScheduledPublisher') ||
        line.contains('BackgroundMessageBroadcastReceiver'),
  );

  if (hasHmsSettings) {
    return false; // Уже добавлено
  }

  // Ищем тег <application> или создаем его
  int applicationCloseIndex = -1;
  bool hasApplicationTag = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.startsWith('<application')) {
      hasApplicationTag = true;
    }
    if (hasApplicationTag && line == '</application>') {
      applicationCloseIndex = i;
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
        newLines.add(hmsAidlService);
        newLines.add('');
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
        newLines.add(hmsAidlService);
        newLines.add('');
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

  file.writeAsStringSync(newLines.join('\n') + '\n');
  return true;
}

/// Удаляет настройки из settings.gradle.kts
bool removeFromSettingsGradle(File file) {
  final lines = file.readAsLinesSync();

  // Проверяем, есть ли плагин
  final hasPlugin = lines.any(
    (line) => line.contains('com.huawei.agconnect'),
  );

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
        (line.contains('com.huawei.hms.core.aidlservice') &&
            (line.contains('<service') || line.contains('AIDLService'))) ||
        line.contains('push_kit_auto_init_enabled') ||
        line.contains('HmsLocalNotificationBootEventReceiver') ||
        line.contains('HmsLocalNotificationScheduledPublisher') ||
        line.contains('BackgroundMessageBroadcastReceiver'),
  );

  if (!hasHmsSettings) {
    return false; // Нечего удалять
  }

  final newLines = <String>[];
  bool skipNextLines = false;
  int skipCount = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Пропускаем service с AIDLService для com.huawei.hms.core.aidlservice
    if (trimmed.contains('<service') && trimmed.contains('AIDLService')) {
      skipNextLines = true;
      skipCount = 0;
      continue;
    }

    if (skipNextLines) {
      skipCount++;
      if (trimmed.contains('</service>')) {
        skipNextLines = false;
        skipCount = 0;
      }
      continue;
    }

    // Пропускаем meta-data для push_kit_auto_init_enabled
    if (trimmed.contains('push_kit_auto_init_enabled')) {
      continue;
    }

    // Пропускаем receiver HmsLocalNotificationBootEventReceiver
    if (trimmed.contains('HmsLocalNotificationBootEventReceiver')) {
      skipNextLines = true;
      skipCount = 0;
      continue;
    }

    if (skipNextLines && skipCount > 0) {
      skipCount++;
      if (trimmed.contains('</receiver>')) {
        skipNextLines = false;
        skipCount = 0;
      }
      continue;
    }

    // Пропускаем receiver HmsLocalNotificationScheduledPublisher
    if (trimmed.contains('HmsLocalNotificationScheduledPublisher')) {
      continue;
    }

    // Пропускаем receiver BackgroundMessageBroadcastReceiver
    if (trimmed.contains('BackgroundMessageBroadcastReceiver')) {
      skipNextLines = true;
      skipCount = 0;
      continue;
    }

    newLines.add(line);
  }

  // Удаляем лишние пустые строки в конце
  while (newLines.isNotEmpty && newLines.last.trim().isEmpty) {
    newLines.removeLast();
  }

  if (newLines.length != lines.length) {
    file.writeAsStringSync(newLines.join('\n') + '\n');
    return true;
  }

  return false;
}

