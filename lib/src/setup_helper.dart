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
        newLines.add(hmsLocalNotificationBootEventReceiver);
        newLines.add('        $hmsLocalNotificationScheduledPublisher');
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
        newLines.add(hmsLocalNotificationBootEventReceiver);
        newLines.add('        $hmsLocalNotificationScheduledPublisher');
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

  // Удаляем пустые блоки (например, пустой plugins {})
  final finalLines = _removeEmptyBlocks(newLines);

  if (finalLines.length != lines.length || foundComment) {
    file.writeAsStringSync(finalLines.join('\n') + '\n');
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
    // Удаляем пустые блоки (например, пустой <queries>)
    final finalLines = _removeEmptyXmlBlocks(newLines);
    file.writeAsStringSync(finalLines.join('\n') + '\n');
    return true;
  }

  return false;
}

/// Удаляет пустые XML блоки из списка строк
List<String> _removeEmptyXmlBlocks(List<String> lines) {
  final result = <String>[];
  int i = 0;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    // Проверяем, является ли строка началом XML блока (например, <queries>)
    if (trimmed.startsWith('<') &&
        trimmed.endsWith('>') &&
        !trimmed.endsWith('/>')) {
      final tagName = trimmed.replaceAll(RegExp(r'[<>]'), '').split(' ')[0];
      final closingTag = '</$tagName>';

      // Ищем закрывающий тег
      int startIndex = i;
      int endIndex = -1;
      bool hasContent = false;

      for (int j = i + 1; j < lines.length; j++) {
        final currentTrimmed = lines[j].trim();
        if (currentTrimmed == closingTag) {
          endIndex = j;
          break;
        }
        // Проверяем, есть ли содержимое между тегами
        if (currentTrimmed.isNotEmpty && !currentTrimmed.startsWith('<!--')) {
          hasContent = true;
        }
      }

      // Если блок пустой (только открывающий и закрывающий теги), пропускаем его
      if (!hasContent && endIndex > startIndex) {
        i = endIndex + 1;
        continue;
      }
    }

    result.add(line);
    i++;
  }

  return result;
}

/// Обновляет build.gradle.kts, добавляя настройки HMS
bool updateBuildGradle(File file) {
  final content = file.readAsStringSync();

  // Проверяем, есть ли уже настройки HMS
  final hasHmsSettings =
      content.contains('developer.huawei.com/repo') ||
      content.contains('com.huawei.agconnect:agcp');

  if (hasHmsSettings) {
    return false; // Уже настроено
  }

  final lines = content.split('\n');
  final newLines = <String>[];

  // 1. Добавляем import в начало, если его нет
  bool hasImport = false;
  for (final line in lines) {
    if (line.trim().startsWith('import org.gradle.api.file.Directory')) {
      hasImport = true;
      break;
    }
  }

  if (!hasImport) {
    newLines.add('import org.gradle.api.file.Directory');
    newLines.add('');
  }

  // 2. Обрабатываем остальные строки
  bool inAllProjects = false;
  bool inRepositories = false;
  bool huaweiRepoAdded = false;
  bool buildscriptAdded = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Если еще не добавили import, добавляем строки как есть
    if (!hasImport && i == 0 && trimmed.isEmpty) {
      continue; // Пропускаем первую пустую строку после добавления import
    }

    // Отслеживаем блок allprojects
    if (trimmed == 'allprojects {') {
      inAllProjects = true;
      newLines.add(line);
      continue;
    }

    if (inAllProjects && trimmed == 'repositories {') {
      inRepositories = true;
      newLines.add(line);
      continue;
    }

    // Добавляем maven Huawei после mavenCentral в repositories
    if (inRepositories && trimmed == 'mavenCentral()' && !huaweiRepoAdded) {
      newLines.add(line);
      newLines.add('        maven(url = "https://developer.huawei.com/repo/")');
      huaweiRepoAdded = true;
      continue;
    }

    if (inRepositories && trimmed == '}') {
      inRepositories = false;
      if (!huaweiRepoAdded) {
        // Если не нашли mavenCentral, добавляем перед закрывающей скобкой
        newLines.add(
          '        maven(url = "https://developer.huawei.com/repo/")',
        );
        huaweiRepoAdded = true;
      }
      newLines.add(line);
      continue;
    }

    if (inAllProjects && trimmed == '}') {
      inAllProjects = false;
      newLines.add(line);
      // Добавляем buildscript блок после allprojects
      if (!buildscriptAdded) {
        newLines.add('');
        newLines.add('buildscript {');
        newLines.add('    repositories {');
        newLines.add('        google()');
        newLines.add('        mavenCentral()');
        newLines.add(
          '        maven(url = "https://developer.huawei.com/repo/")',
        );
        newLines.add('        gradlePluginPortal()');
        newLines.add('    }');
        newLines.add('    dependencies {');
        newLines.add(
          '        classpath("com.android.tools.build:gradle:8.8.1")',
        );
        newLines.add(
          '        classpath("com.huawei.agconnect:agcp:1.9.1.303")',
        );
        newLines.add(
          '        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")',
        );
        newLines.add('    }');
        newLines.add('}');
        buildscriptAdded = true;
      }
      continue;
    }

    newLines.add(line);
  }

  // Сохраняем файл как есть (не объединяем subprojects блоки)
  file.writeAsStringSync(newLines.join('\n') + '\n');
  return true;
}

/// Удаляет настройки HMS из build.gradle.kts
bool removeFromBuildGradle(File file) {
  final content = file.readAsStringSync();

  // Проверяем, есть ли настройки HMS
  final hasHmsSettings =
      content.contains('developer.huawei.com/repo') ||
      content.contains('com.huawei.agconnect:agcp');

  if (!hasHmsSettings) {
    return false; // Нечего удалять
  }

  final lines = content.split('\n');
  final newLines = <String>[];

  bool inBuildscript = false;
  int buildscriptBraceCount = 0;
  bool inAllProjectsRepositories = false;
  bool skipImport = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Пропускаем import, если он был добавлен нами (в начале файла)
    if (trimmed == 'import org.gradle.api.file.Directory' && i == 0) {
      skipImport = true;
      continue;
    }

    if (skipImport && trimmed.isEmpty) {
      skipImport = false;
      continue;
    }
    skipImport = false;

    // Удаляем maven Huawei из allprojects.repositories
    if (trimmed == 'allprojects {') {
      inAllProjectsRepositories = false;
      newLines.add(line);
      continue;
    }

    if (trimmed == 'repositories {' &&
        i > 0 &&
        lines[i - 1].trim().contains('allprojects')) {
      inAllProjectsRepositories = true;
      newLines.add(line);
      continue;
    }

    if (inAllProjectsRepositories &&
        trimmed.contains('developer.huawei.com/repo')) {
      continue; // Пропускаем эту строку
    }

    if (inAllProjectsRepositories && trimmed == '}') {
      inAllProjectsRepositories = false;
      newLines.add(line);
      continue;
    }

    // Удаляем весь блок buildscript с правильным подсчетом скобок
    if (trimmed == 'buildscript {') {
      inBuildscript = true;
      buildscriptBraceCount = 1;
      continue; // Пропускаем открывающую скобку buildscript
    }

    if (inBuildscript) {
      // Считаем открывающие и закрывающие скобки
      buildscriptBraceCount += trimmed.split('{').length - 1;
      buildscriptBraceCount -= trimmed.split('}').length - 1;

      if (buildscriptBraceCount == 0) {
        // Блок buildscript закрыт
        inBuildscript = false;
        continue; // Пропускаем закрывающую скобку buildscript
      }
      continue; // Пропускаем все строки внутри buildscript
    }

    newLines.add(line);
  }

  // Удаляем лишние пустые строки (более одной подряд)
  final cleanedLines = <String>[];
  bool previousEmpty = false;
  for (int i = 0; i < newLines.length; i++) {
    final isEmpty = newLines[i].trim().isEmpty;
    if (isEmpty && previousEmpty) {
      continue; // Пропускаем повторяющиеся пустые строки
    }
    previousEmpty = isEmpty;
    cleanedLines.add(newLines[i]);
  }

  // Удаляем пустые строки в конце
  while (cleanedLines.isNotEmpty && cleanedLines.last.trim().isEmpty) {
    cleanedLines.removeLast();
  }

  // Удаляем пустые блоки
  final finalLines = _removeEmptyBlocks(cleanedLines);

  file.writeAsStringSync(finalLines.join('\n') + '\n');
  return true;
}

/// Удаляет пустые блоки из списка строк
List<String> _removeEmptyBlocks(List<String> lines) {
  final result = <String>[];
  int i = 0;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    // Проверяем, является ли строка началом блока (например, "buildscript {" или "plugins {")
    if (trimmed.endsWith('{') && !trimmed.startsWith('//')) {
      // Ищем закрывающую скобку этого блока
      int braceCount = 1;
      int startIndex = i;
      int endIndex = i;
      final contentLines = <String>[];

      for (int j = i + 1; j < lines.length && braceCount > 0; j++) {
        final currentLine = lines[j];
        final currentTrimmed = currentLine.trim();

        if (currentTrimmed.contains('{')) {
          braceCount += currentTrimmed.split('{').length - 1;
        }
        if (currentTrimmed.contains('}')) {
          braceCount -= currentTrimmed.split('}').length - 1;
        }

        // Сохраняем содержимое между скобками (игнорируя пустые строки и комментарии)
        if (braceCount > 0) {
          if (currentTrimmed.isNotEmpty && !currentTrimmed.startsWith('//')) {
            contentLines.add(currentTrimmed);
          }
        }

        if (braceCount == 0) {
          endIndex = j;
          break;
        }
      }

      // Если блок пустой (нет содержимого между скобками), пропускаем его
      if (contentLines.isEmpty && endIndex > startIndex) {
        i = endIndex + 1;
        continue;
      }
    }

    result.add(line);
    i++;
  }

  return result;
}
