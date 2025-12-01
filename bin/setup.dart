#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:hms_services/hms_services_setup.dart';

/// Скрипт для автоматической настройки Android проекта для использования
/// плагина hms_services.
///
/// Этот скрипт автоматически добавляет необходимые плагины Huawei Services
/// в файлы settings.gradle.kts и AndroidManifest.xml.
///
/// Использование:
///   dart run hms_services:setup

Future<void> main(List<String> args) async {
  print('🔧 Настройка Android проекта для плагина hms_services...\n');

  final result = await setupHmsServices();

  // Выводим все сообщения из результата
  for (final message in result.messages) {
    print(message);
  }

  // Завершаем с ошибкой, если были ошибки
  if (!result.changesMade && result.messages.any((m) => m.contains('❌'))) {
    exit(1);
  }
}

