#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:hms_services/hms_services_setup.dart';

/// Скрипт для удаления настроек Android проекта для плагина hms_services.
///
/// Этот скрипт автоматически удаляет плагины Huawei Services
/// из файлов settings.gradle.kts и AndroidManifest.xml.
///
/// Использование:
///   dart run hms_services:cleanup

Future<void> main(List<String> args) async {
  print('🗑️  Удаление настроек Android проекта для плагина hms_services...\n');

  final result = await cleanupHmsServices();

  // Выводим все сообщения из результата
  for (final message in result.messages) {
    print(message);
  }

  // Завершаем с ошибкой, если были ошибки
  if (!result.changesMade && result.messages.any((m) => m.contains('❌'))) {
    exit(1);
  }
}

