/// Внутренний модуль с общей логикой для настройки и очистки Android проекта.
library;

import 'dart:io';

/// Результат выполнения операции настройки/очистки.
class SetupResult {
  /// Были ли внесены изменения в файлы.
  final bool changesMade;

  /// Сообщения о выполненных операциях.
  final List<String> messages;

  SetupResult({required this.changesMade, required this.messages});
}

/// Тип синтаксиса Gradle файла
enum GradleSyntaxType {
  kotlinDsl, // .gradle.kts
  groovy, // .gradle
}

/// Константы для плагинов и настроек HMS (Kotlin DSL)
const String agconnectPluginKts =
    'id("com.huawei.agconnect") version "1.9.1.303" apply false';
const String agconnectApplyKts = 'id("com.huawei.agconnect")';
const String installReferrerKts =
    'implementation("com.android.installreferrer:installreferrer:2.2")';

/// Константы для плагинов и настроек HMS (Groovy)
const String agconnectPluginGroovy =
    "id 'com.huawei.agconnect' version '1.9.1.303' apply false";
const String agconnectApplyGroovy = "apply plugin: 'com.huawei.agconnect'";
const String installReferrerGroovy =
    "implementation 'com.android.installreferrer:installreferrer:2.2'";

/// Определяет тип синтаксиса Gradle файла по расширению
GradleSyntaxType _getGradleSyntaxType(File file) {
  final path = file.path;
  if (path.endsWith('.gradle.kts')) {
    return GradleSyntaxType.kotlinDsl;
  } else if (path.endsWith('.gradle')) {
    return GradleSyntaxType.groovy;
  }
  // По умолчанию считаем Kotlin DSL
  return GradleSyntaxType.kotlinDsl;
}

/// Находит файл settings.gradle (проверяет оба варианта: .kts и .gradle)
File? findSettingsGradleFile(Directory androidDir) {
  final ktsFile = File('${androidDir.path}/settings.gradle.kts');
  if (ktsFile.existsSync()) {
    return ktsFile;
  }
  final gradleFile = File('${androidDir.path}/settings.gradle');
  if (gradleFile.existsSync()) {
    return gradleFile;
  }
  return null;
}

/// Находит файл build.gradle (проверяет оба варианта: .kts и .gradle)
File? findBuildGradleFile(Directory androidDir) {
  final ktsFile = File('${androidDir.path}/build.gradle.kts');
  if (ktsFile.existsSync()) {
    return ktsFile;
  }
  final gradleFile = File('${androidDir.path}/build.gradle');
  if (gradleFile.existsSync()) {
    return gradleFile;
  }
  return null;
}

/// Находит файл app/build.gradle (проверяет оба варианта: .kts и .gradle)
File? findAppBuildGradleFile(Directory androidDir) {
  final ktsFile = File('${androidDir.path}/app/build.gradle.kts');
  if (ktsFile.existsSync()) {
    return ktsFile;
  }
  final gradleFile = File('${androidDir.path}/app/build.gradle');
  if (gradleFile.existsSync()) {
    return gradleFile;
  }
  return null;
}

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

/// Содержимое для proguard-rules.pro
const String proguardRulesContent = '''-ignorewarnings
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes EnclosingMethod
-keep class com.hianalytics.android.**{*;}
-keep class com.huawei.updatesdk.**{*;}
-keep class com.huawei.hms.**{*;}
## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
-keep class com.huawei.hms.flutter.** { *; }
-repackageclasses
''';

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

/// Находит границы блока в файле (например, plugins { ... })
/// Возвращает (startIndex, endIndex) или null, если блок не найден
(int, int)? _findBlockBounds(
  List<String> lines,
  String blockName,
  int startFrom,
) {
  int? blockStart;
  int blockDepth = 0;
  bool inBlock = false;

  for (int i = startFrom; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Находим начало блока (например, "plugins {" или "plugins{")
    if (!inBlock && trimmed.startsWith(blockName) && trimmed.contains('{')) {
      blockStart = i;
      inBlock = true;
      blockDepth = 1;
      // Проверяем, не закрылся ли блок в той же строке
      final openBraces = trimmed.split('{').length - 1;
      final closeBraces = trimmed.split('}').length - 1;
      blockDepth +=
          openBraces -
          closeBraces -
          1; // -1 потому что уже посчитали начальную {
      if (blockDepth == 0) {
        return (blockStart, i);
      }
      continue;
    }

    if (inBlock) {
      // Считаем вложенные скобки в строке
      final openBraces = line.split('{').length - 1;
      final closeBraces = line.split('}').length - 1;
      blockDepth += openBraces - closeBraces;

      // Если блок закрылся
      if (blockDepth == 0 && blockStart != null) {
        return (blockStart, i);
      }
    }
  }

  return null;
}

/// Обновляет settings.gradle(.kts), добавляя плагин Huawei AGConnect
bool updateSettingsGradle(File file) {
  final content = file.readAsStringSync();
  final syntaxType = _getGradleSyntaxType(file);

  // Определяем константы в зависимости от типа синтаксиса
  final String agconnectPlugin;
  if (syntaxType == GradleSyntaxType.kotlinDsl) {
    agconnectPlugin = agconnectPluginKts;
  } else {
    agconnectPlugin = agconnectPluginGroovy;
  }

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

  file.writeAsStringSync('${newLines.join('\n')}\n\n');
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
    file.writeAsStringSync('${finalLines.join('\n')}\n\n');
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
    file.writeAsStringSync('${finalLines.join('\n')}\n\n');
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
  file.writeAsStringSync('${newLines.join('\n')}\n\n');
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

  file.writeAsStringSync('${finalLines.join('\n')}\n');
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

/// Создает или обновляет proguard-rules.pro
bool updateProguardRules(File file) {
  // Проверяем, есть ли уже настройки HMS в файле
  if (file.existsSync()) {
    final content = file.readAsStringSync();
    if (content.contains('com.huawei.hms') || content.contains('hianalytics')) {
      return false; // Уже настроено
    }
    // Если файл существует, но не содержит HMS правил, добавляем их
    final newContent = '$content\n$proguardRulesContent';
    file.writeAsStringSync(newContent);
    return true;
  } else {
    // Если файла нет, создаем его
    file.createSync(recursive: true);
    file.writeAsStringSync(proguardRulesContent);
    return true;
  }
}

/// Удаляет настройки HMS из proguard-rules.pro
/// Если файл становится пустым, удаляет его
bool removeFromProguardRules(File file) {
  if (!file.existsSync()) {
    return false; // Файла нет, нечего удалять
  }

  final content = file.readAsStringSync();

  // Проверяем, есть ли настройки HMS
  if (!content.contains('com.huawei.hms') && !content.contains('hianalytics')) {
    return false; // Нечего удалять
  }

  // Получаем список строк, которые нужно удалить (из proguardRulesContent)
  final rulesToRemove = proguardRulesContent
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  final lines = content.split('\n');
  final newLines = <String>[];

  // Удаляем строки, которые точно совпадают с нашими правилами
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Пропускаем строки, которые точно совпадают с нашими правилами
    if (rulesToRemove.contains(trimmed)) {
      continue;
    }

    // Также удаляем строки, которые содержат HMS классы
    if (trimmed.contains('com.huawei.hms') ||
        trimmed.contains('hianalytics') ||
        trimmed.contains('huawei.updatesdk') ||
        trimmed.contains('huawei.hms.flutter')) {
      continue;
    }

    // Удаляем комментарий "## Flutter wrapper" только если он идет перед HMS правилами
    if (trimmed == '## Flutter wrapper') {
      // Проверяем следующие строки - если там HMS правила, пропускаем комментарий
      bool hasHmsAfter = false;
      for (int j = i + 1; j < lines.length && j < i + 15; j++) {
        final nextTrimmed = lines[j].trim();
        if (nextTrimmed.isEmpty) continue;
        if (nextTrimmed.contains('com.huawei.hms') ||
            nextTrimmed.contains('huawei.hms.flutter') ||
            nextTrimmed.contains('hianalytics')) {
          hasHmsAfter = true;
          break;
        }
        // Если встретили другую строку (не HMS), прекращаем проверку
        if (!nextTrimmed.startsWith('-') && !nextTrimmed.startsWith('#')) {
          break;
        }
      }
      if (hasHmsAfter) {
        continue; // Пропускаем комментарий
      }
    }

    newLines.add(line);
  }

  // Удаляем пустые строки в конце
  while (newLines.isNotEmpty && newLines.last.trim().isEmpty) {
    newLines.removeLast();
  }

  // Удаляем множественные пустые строки подряд
  final cleanedLines = <String>[];
  bool previousEmpty = false;
  for (final line in newLines) {
    final isEmpty = line.trim().isEmpty;
    if (isEmpty && previousEmpty) {
      continue; // Пропускаем повторяющиеся пустые строки
    }
    previousEmpty = isEmpty;
    cleanedLines.add(line);
  }

  // Если файл стал пустым, удаляем его
  final finalContent = cleanedLines.join('\n').trim();
  if (finalContent.isEmpty) {
    file.deleteSync();
    return true;
  }

  file.writeAsStringSync('$finalContent\n');
  return true;
}

/// Обновляет app/build.gradle.kts, добавляя proguardFiles, плагины и зависимости
bool updateAppBuildGradle(File file, File proguardFile) {
  // Добавляем плагин agconnect в блок plugins
  updateAppBuildGradlePlugins(file);

  // Добавляем зависимость installreferrer
  addDependenciesToAppBuildGradle(file);

  final content = file.readAsStringSync();
  final lines = content.split('\n');

  // Проверяем построчно, есть ли уже proguardFiles в блоке release
  bool hasProguardFiles = false;
  bool inReleaseCheck = false;
  bool foundProguardStart = false;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == 'release {') {
      inReleaseCheck = true;
      foundProguardStart = false;
    } else if (trimmed == '}') {
      if (inReleaseCheck) {
        inReleaseCheck = false;
        foundProguardStart = false;
      }
    } else if (inReleaseCheck) {
      if (trimmed.contains('proguardFiles')) {
        foundProguardStart = true;
      }
      if (foundProguardStart && trimmed.contains('proguard-rules.pro')) {
        hasProguardFiles = true;
        break;
      }
    }
  }

  // Если файл proguard-rules.pro не существует, не добавляем proguardFiles
  bool shouldAddProguardFiles = proguardFile.existsSync() && !hasProguardFiles;

  // Проверяем, есть ли уже нужные настройки
  bool hasReleaseMinify = false;
  bool hasReleaseShrink = false;
  bool hasDebugMinify = false;
  bool hasDebugShrink = false;
  bool hasDebugDebuggable = false;
  bool hasDebugBlock = false;
  bool hasDebugSigningConfig = false;
  bool hasReleaseSigningConfig = false;

  bool inDebugBlock = false;
  bool inReleaseBlock = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed == 'debug {') {
      hasDebugBlock = true;
      inDebugBlock = true;
      inReleaseBlock = false;
    } else if (trimmed == 'release {') {
      inReleaseBlock = true;
      inDebugBlock = false;
    } else if (trimmed == '}') {
      inDebugBlock = false;
      inReleaseBlock = false;
    } else if (inReleaseBlock) {
      if (trimmed == 'isMinifyEnabled = true') {
        hasReleaseMinify = true;
      }
      if (trimmed == 'isShrinkResources = true') {
        hasReleaseShrink = true;
      }
      if (trimmed.contains('signingConfig') &&
          trimmed.contains('getByName("release")')) {
        hasReleaseSigningConfig = true;
      }
    } else if (inDebugBlock) {
      if (trimmed == 'isMinifyEnabled = true') {
        hasDebugMinify = true;
      }
      if (trimmed == 'isShrinkResources = true') {
        hasDebugShrink = true;
      }
      if (trimmed == 'isDebuggable = true') {
        hasDebugDebuggable = true;
      }
      if (trimmed.contains('signingConfig') &&
          trimmed.contains('getByName("release")')) {
        hasDebugSigningConfig = true;
      }
    }
  }

  final newLines = <String>[];
  bool inBuildTypes = false;
  // inReleaseBlock и inDebugBlock уже определены выше
  bool proguardFilesAdded = false;
  bool releaseSettingsAdded = false;
  bool debugSettingsAdded = false;
  bool releaseSigningConfigUpdated = false;

  // Сбрасываем флаги для нового цикла
  inReleaseBlock = false;
  inDebugBlock = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Отслеживаем блок buildTypes
    if (trimmed == 'buildTypes {') {
      inBuildTypes = true;
      newLines.add(line);
      continue;
    }

    // Отслеживаем блок release
    if (inBuildTypes && trimmed == 'release {') {
      inReleaseBlock = true;
      inDebugBlock = false;
      newLines.add(line);
      continue;
    }

    // Отслеживаем блок debug
    if (inBuildTypes && trimmed == 'debug {') {
      inDebugBlock = true;
      inReleaseBlock = false;
      newLines.add(line);
      continue;
    }

    // Заменяем signingConfig в блоке release с "debug" на "release"
    if (inReleaseBlock &&
        trimmed.contains('signingConfig') &&
        trimmed.contains('getByName("debug")')) {
      newLines.add(
        '            signingConfig = signingConfigs.getByName("release")',
      );
      releaseSigningConfigUpdated = true;
      continue;
    }

    // Пропускаем строки с signingConfig в блоке release, если уже есть с "release"
    if (inReleaseBlock &&
        trimmed.contains('signingConfig') &&
        trimmed.contains('getByName("release")')) {
      newLines.add(line);
      continue;
    }

    // Пропускаем строки с signingConfig в блоке debug (они уже учтены в hasDebugSigningConfig)
    if (inDebugBlock &&
        trimmed.contains('signingConfig') &&
        trimmed.contains('getByName("release")')) {
      newLines.add(line);
      continue;
    }

    // Добавляем настройки перед закрывающей скобкой release
    if (inReleaseBlock && trimmed == '}') {
      inReleaseBlock = false;
      // Если signingConfig еще не обновлен и его нет, добавляем его
      if (!releaseSigningConfigUpdated && !hasReleaseSigningConfig) {
        newLines.add(
          '            signingConfig = signingConfigs.getByName("release")',
        );
      }
      if (shouldAddProguardFiles && !proguardFilesAdded) {
        newLines.add('            proguardFiles(');
        newLines.add(
          '                getDefaultProguardFile("proguard-android.txt"),',
        );
        newLines.add('                "proguard-rules.pro"');
        newLines.add('            )');
        proguardFilesAdded = true;
      }
      if (!releaseSettingsAdded && (!hasReleaseMinify || !hasReleaseShrink)) {
        if (!hasReleaseMinify) {
          newLines.add('            isMinifyEnabled = true');
        }
        if (!hasReleaseShrink) {
          newLines.add('            isShrinkResources = true');
        }
        releaseSettingsAdded = true;
      }
      newLines.add(line);
      continue;
    }

    // Добавляем настройки перед закрывающей скобкой debug
    if (inDebugBlock && trimmed == '}') {
      inDebugBlock = false;
      // Если signingConfig еще не добавлен, добавляем его
      if (!hasDebugSigningConfig) {
        newLines.add(
          '            signingConfig = signingConfigs.getByName("release")',
        );
      }
      if (!debugSettingsAdded &&
          (!hasDebugMinify || !hasDebugShrink || !hasDebugDebuggable)) {
        if (!hasDebugMinify) {
          newLines.add('            isMinifyEnabled = true');
        }
        if (!hasDebugShrink) {
          newLines.add('            isShrinkResources = true');
        }
        if (!hasDebugDebuggable) {
          newLines.add('            isDebuggable = true');
        }
        debugSettingsAdded = true;
      }
      newLines.add(line);
      continue;
    }

    if (inBuildTypes && trimmed == '}') {
      inBuildTypes = false;
      // Если нет блока debug, создаем его перед закрывающей скобкой buildTypes
      if (!hasDebugBlock && !debugSettingsAdded) {
        newLines.add('        debug {');
        newLines.add(
          '            signingConfig = signingConfigs.getByName("release")',
        );
        newLines.add('            isMinifyEnabled = true');
        newLines.add('            isShrinkResources = true');
        newLines.add('            isDebuggable = true');
        newLines.add('        }');
        debugSettingsAdded = true;
      }
      newLines.add(line);
      continue;
    }

    newLines.add(line);
  }

  // Удаляем пустые строки в конце
  while (newLines.isNotEmpty && newLines.last.trim().isEmpty) {
    newLines.removeLast();
  }

  file.writeAsStringSync('${newLines.join('\n')}\n');
  return true;
}

/// Обновляет app/build.gradle(.kts), добавляя плагин agconnect в блок plugins
bool updateAppBuildGradlePlugins(File file) {
  final lines = file.readAsLinesSync();
  final syntaxType = _getGradleSyntaxType(file);

  // Определяем константы в зависимости от типа синтаксиса
  final String agconnectApply;
  if (syntaxType == GradleSyntaxType.kotlinDsl) {
    agconnectApply = agconnectApplyKts;
  } else {
    agconnectApply = agconnectApplyGroovy;
  }

  // Проверяем, есть ли уже плагин agconnect
  final hasPlugin = lines.any(
    (line) =>
        line.contains('com.huawei.agconnect') &&
        !line.contains('version') &&
        !line.contains('apply false'),
  );

  if (hasPlugin) {
    return false; // Уже настроено
  }

  // Ищем блок plugins
  final blockBounds = _findBlockBounds(lines, 'plugins', 0);
  if (blockBounds != null) {
    final (blockStart, blockEnd) = blockBounds;

    // Добавляем плагин перед закрывающей скобкой
    final newLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      if (i == blockEnd) {
        // Вставляем перед закрывающей скобкой
        newLines.add('    // Плагин для hms_services:');
        newLines.add('    $agconnectApply');
      }
      newLines.add(lines[i]);
    }

    file.writeAsStringSync('${newLines.join('\n')}\n');
    return true;
  } else {
    // Если блока plugins нет, добавляем в начало файла
    final newLines = <String>[];
    newLines.add('plugins {');
    newLines.add('    // Плагин для hms_services:');
    newLines.add('    $agconnectApply');
    newLines.add('}');
    newLines.add('');
    newLines.addAll(lines);

    file.writeAsStringSync('${newLines.join('\n')}\n');
    return true;
  }
}

/// Добавляет зависимости в app/build.gradle(.kts)
bool addDependenciesToAppBuildGradle(File file) {
  final lines = file.readAsLinesSync();
  final syntaxType = _getGradleSyntaxType(file);

  // Определяем константы в зависимости от типа синтаксиса
  final String installReferrer;
  if (syntaxType == GradleSyntaxType.kotlinDsl) {
    installReferrer = installReferrerKts;
  } else {
    installReferrer = installReferrerGroovy;
  }

  // Проверяем, есть ли уже зависимость installreferrer
  final hasDependency = lines.any(
    (line) => line.contains('installreferrer:2.2'),
  );

  if (hasDependency) {
    return false; // Уже добавлено
  }

  // Ищем блок dependencies
  final blockBounds = _findBlockBounds(lines, 'dependencies', 0);
  if (blockBounds != null) {
    final (blockStart, blockEnd) = blockBounds;

    // Добавляем зависимость перед закрывающей скобкой
    final newLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      if (i == blockEnd) {
        // Вставляем перед закрывающей скобкой
        newLines.add('    // Зависимость для hms_services:');
        newLines.add('    $installReferrer');
      }
      newLines.add(lines[i]);
    }

    file.writeAsStringSync('${newLines.join('\n')}\n');
    return true;
  } else {
    // Блока dependencies нет, создаем его после блока flutter
    int flutterBlockEnd = -1;
    final flutterBlockBounds = _findBlockBounds(lines, 'flutter', 0);
    if (flutterBlockBounds != null) {
      flutterBlockEnd = flutterBlockBounds.$2;
    }

    final newLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      newLines.add(lines[i]);
      if (i == flutterBlockEnd ||
          (flutterBlockEnd == -1 && i == lines.length - 1)) {
        newLines.add('');
        newLines.add('dependencies {');
        newLines.add('    // Зависимость для hms_services:');
        newLines.add('    $installReferrer');
        newLines.add('}');
      }
    }

    file.writeAsStringSync('${newLines.join('\n')}\n');
    return true;
  }
}

/// Удаляет плагин agconnect из app/build.gradle.kts
bool removeAppBuildGradlePlugins(File file) {
  final lines = file.readAsLinesSync();

  // Проверяем, есть ли плагин agconnect
  final hasPlugin = lines.any(
    (line) =>
        line.contains('com.huawei.agconnect') &&
        !line.contains('version') &&
        !line.contains('apply false'),
  );

  if (!hasPlugin) {
    return false; // Нечего удалять
  }

  // Ищем блок plugins
  final blockBounds = _findBlockBounds(lines, 'plugins', 0);

  final newLines = <String>[];
  bool foundChanges = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Пропускаем комментарий
    if (trimmed.contains('// Плагин для hms_services:') ||
        trimmed.contains('//Плагин для hms_services:')) {
      foundChanges = true;
      continue;
    }

    // Пропускаем строки с плагином agconnect (без version и apply false)
    if (trimmed.contains('com.huawei.agconnect') &&
        !trimmed.contains('version') &&
        !trimmed.contains('apply false')) {
      foundChanges = true;
      continue;
    }

    newLines.add(line);
  }

  // Проверяем, нужно ли удалить пустой блок plugins
  if (blockBounds != null && foundChanges) {
    final (blockStart, blockEnd) = blockBounds;

    // Проверяем, остались ли в блоке только наши строки
    bool hasOtherContent = false;
    for (int i = blockStart + 1; i < blockEnd && i < newLines.length; i++) {
      final trimmed = newLines[i].trim();
      if (trimmed.isNotEmpty &&
          !trimmed.contains('// Плагин для hms_services:') &&
          !trimmed.contains('com.huawei.agconnect')) {
        hasOtherContent = true;
        break;
      }
    }

    // Если блока plugins не осталось содержимого, удаляем весь блок
    if (!hasOtherContent &&
        blockStart < newLines.length &&
        blockEnd < newLines.length) {
      final finalLines = <String>[];
      for (int i = 0; i < newLines.length; i++) {
        if (i < blockStart || i > blockEnd) {
          finalLines.add(newLines[i]);
        }
      }

      // Удаляем лишние пустые строки
      while (finalLines.isNotEmpty && finalLines.last.trim().isEmpty) {
        finalLines.removeLast();
      }

      newLines.clear();
      newLines.addAll(finalLines);
    }
  }

  // Удаляем лишние пустые строки в конце
  while (newLines.isNotEmpty && newLines.last.trim().isEmpty) {
    newLines.removeLast();
  }

  if (foundChanges) {
    file.writeAsStringSync('${newLines.join('\n')}\n');
    return true;
  }

  return false;
}

/// Удаляет зависимости из app/build.gradle.kts
bool removeDependenciesFromAppBuildGradle(File file) {
  final lines = file.readAsLinesSync();

  // Проверяем, есть ли зависимость installreferrer
  final hasDependency = lines.any(
    (line) => line.contains('installreferrer:2.2'),
  );

  if (!hasDependency) {
    return false; // Нечего удалять
  }

  // Ищем блок dependencies
  final blockBounds = _findBlockBounds(lines, 'dependencies', 0);
  if (blockBounds == null) {
    return false; // Блок dependencies не найден
  }

  final (blockStart, blockEnd) = blockBounds;
  final newLines = <String>[];
  bool foundChanges = false;

  // Обрабатываем строки - удаляем только нашу зависимость
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Если это внутри блока dependencies
    if (i > blockStart && i < blockEnd) {
      // Пропускаем комментарий
      if (trimmed.contains('// Зависимость для hms_services:') ||
          trimmed.contains('//Зависимость для hms_services:')) {
        foundChanges = true;
        continue;
      }

      // Пропускаем зависимость installreferrer
      if (trimmed.contains('installreferrer:2.2')) {
        foundChanges = true;
        continue;
      }
    }

    // Оставляем все остальные строки
    newLines.add(line);
  }

  // Проверяем, остался ли блок dependencies пустым
  if (foundChanges) {
    // Находим блок dependencies в новом массиве после удаления
    final newBlockBounds = _findBlockBounds(newLines, 'dependencies', 0);
    if (newBlockBounds != null) {
      final (newBlockStart, newBlockEnd) = newBlockBounds;

      // Проверяем, пуст ли блок (содержит только пустые строки и комментарии)
      bool hasContent = false;
      for (int i = newBlockStart + 1; i < newBlockEnd; i++) {
        final trimmed = newLines[i].trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('//')) {
          hasContent = true;
          break;
        }
      }

      // Если блок пуст, удаляем его полностью
      if (!hasContent) {
        final finalLines = <String>[];
        for (int i = 0; i < newLines.length; i++) {
          if (i < newBlockStart || i > newBlockEnd) {
            finalLines.add(newLines[i]);
          }
        }

        // Удаляем лишние пустые строки
        while (finalLines.isNotEmpty && finalLines.last.trim().isEmpty) {
          finalLines.removeLast();
        }

        newLines.clear();
        newLines.addAll(finalLines);
      }
    }
  }

  // Удаляем лишние пустые строки в конце
  while (newLines.isNotEmpty && newLines.last.trim().isEmpty) {
    newLines.removeLast();
  }

  if (foundChanges) {
    file.writeAsStringSync('${newLines.join('\n')}\n');
    return true;
  }

  return false;
}

/// Удаляет настройки из app/build.gradle.kts (proguardFiles, плагины, зависимости).
///
/// [removeDebugOptimizations] – если `true`, дополнительно удаляет строки
/// `isMinifyEnabled = true` и `isShrinkResources = true` только из блока
/// `debug { ... }`. Это используется, когда `proguard-rules.pro` отсутствует.
bool removeFromAppBuildGradle(
  File file, {
  bool removeDebugOptimizations = false,
}) {
  bool changesMade = false;

  // Удаляем плагин agconnect
  if (removeAppBuildGradlePlugins(file)) {
    changesMade = true;
  }

  // Удаляем зависимость installreferrer
  if (removeDependenciesFromAppBuildGradle(file)) {
    changesMade = true;
  }

  // Удаляем proguardFiles
  final content = file.readAsStringSync();

  // Проверяем построчно, есть ли proguardFiles
  final lines = content.split('\n');
  bool hasProguardFiles = false;
  bool foundProguardFiles = false;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.contains('proguardFiles')) {
      foundProguardFiles = true;
    }
    if (foundProguardFiles && trimmed.contains('proguard-rules.pro')) {
      hasProguardFiles = true;
      break;
    }
  }

  if (!hasProguardFiles) {
    return changesMade; // Возвращаем true, если были другие изменения
  }

  final newLines = <String>[];
  bool inProguardFiles = false;
  int parenCount = 0;
  bool inDebugBlock = false;
  bool inReleaseBlockLocal = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Отслеживаем начало/конец блока debug и release
    if (trimmed == 'debug {') {
      inDebugBlock = true;
      newLines.add(line);
      continue;
    }
    if (trimmed == 'release {') {
      inReleaseBlockLocal = true;
      newLines.add(line);
      continue;
    }
    if (inDebugBlock && trimmed == '}') {
      inDebugBlock = false;
      newLines.add(line);
      continue;
    }
    if (inReleaseBlockLocal && trimmed == '}') {
      inReleaseBlockLocal = false;
      newLines.add(line);
      continue;
    }

    // Ищем начало блока proguardFiles
    if (trimmed.contains('proguardFiles') && line.contains('(')) {
      inProguardFiles = true;
      // Считаем скобки в этой строке
      parenCount = 0;
      for (int j = 0; j < line.length; j++) {
        if (line[j] == '(') parenCount++;
        if (line[j] == ')') parenCount--;
      }
      // Если в этой строке уже закрыта, пропускаем её и продолжаем
      if (parenCount <= 0) {
        inProguardFiles = false;
        parenCount = 0;
        continue;
      }
      continue; // Пропускаем строку с proguardFiles(
    }

    if (inProguardFiles) {
      // Считаем скобки в текущей строке
      for (int j = 0; j < line.length; j++) {
        if (line[j] == '(') parenCount++;
        if (line[j] == ')') parenCount--;
      }

      // Если все скобки закрыты, блок завершен
      if (parenCount <= 0) {
        inProguardFiles = false;
        parenCount = 0;
        continue; // Пропускаем последнюю строку блока
      }
      continue; // Пропускаем все строки внутри блока
    }

    // Опционально убираем оптимизации из debug/release-блоков,
    // если proguard отсутствует
    if (removeDebugOptimizations &&
        (inDebugBlock || inReleaseBlockLocal) &&
        (trimmed == 'isMinifyEnabled = true' ||
            trimmed == 'isShrinkResources = true')) {
      continue;
    }

    newLines.add(line);
  }

  // Удаляем пустые строки в конце
  while (newLines.isNotEmpty && newLines.last.trim().isEmpty) {
    newLines.removeLast();
  }

  file.writeAsStringSync('${newLines.join('\n')}\n');
  return true;
}
