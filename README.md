## hms_services

Плагин для Flutter, который помогает настроить Android‑проект под Huawei Mobile
Services (HMS) и предоставляет удобный адаптер для работы с push‑уведомлениями
через Huawei Push Kit.

- **Автонастройка Android‑проекта**: Gradle, Manifest, ProGuard.
- **Безопасная очистка**: удаляются только HMS‑строки, чужие настройки не
  трогаются.
- **Messaging‑адаптер**: единый API для работы с Huawei Push.
- **Ads‑адаптер**: получение рекламного ID через Huawei Ads.
- **Главный фасад**: `HmsServices` для инициализации сервисов.

---

## Установка

Добавьте зависимость в `pubspec.yaml` вашего приложения:

```yaml
dependencies:
  hms_services:
    git:
      url: https://github.com/your-org/hms_services.git
      ref: main
```

В `android/app/build.gradle(.kts)` и манифест ничего вручную править не нужно –
за это отвечает скрипт настройки.

---

## Автонастройка Android‑проекта

Плагин содержит два CLI‑скрипта:

- **setup** – добавляет все необходимые HMS‑настройки.
- **cleanup** – аккуратно их удаляет.

### Требования

- Flutter 3.3+
- Android‑часть проекта уже создана (`flutter create`).
- Поддерживаются оба варианта Gradle‑скриптов:
  - `*.gradle.kts` (Kotlin DSL)
  - `*.gradle` (Groovy)

### Что делает `setup`

Из корня Flutter‑проекта выполните:

```bash
dart run hms_services:setup
```

Скрипт:

- Находит директорию `android` и автоматически определяет:
  - `settings.gradle(.kts)`
  - `build.gradle(.kts)`
  - `app/build.gradle(.kts)`
  - `app/src/main/AndroidManifest.xml`
  - `proguard-rules.pro` (создаётся при отсутствии)
- Вносит изменения **построчно** с учётом типа файла (`.kts`/`.gradle`) и не
  добавляет лишних пустых строк.

Основные действия:

- **`settings.gradle(.kts)`**
  - Добавляет необходимые HMS‑плагины (через `plugins { ... }`).
- **Корневой `build.gradle(.kts)`**
  - Подключает Huawei Maven‑репозиторий.
  - Добавляет нужный `buildscript`‑блок (если требуется).
- **`app/build.gradle(.kts)`**
  - Добавляет плагин `com.huawei.agconnect`.
  - Добавляет зависимость
    `implementation("com.android.installreferrer:installreferrer:2.2")`.
  - В `buildTypes`:
    - В `release`:
      - Подключает `proguardFiles(...)` с `proguard-rules.pro` (если файл
        существует).
      - Добавляет `isMinifyEnabled = true` и `isShrinkResources = true`, если
        их ещё нет.
      - Заменяет
        `signingConfig = signingConfigs.getByName("debug")` на
        `signingConfig = signingConfigs.getByName("release")`.
    - В `debug`:
      - Гарантирует наличие блока `debug { ... }` (создаёт при отсутствии).
      - Добавляет `isMinifyEnabled = true`, `isShrinkResources = true`,
        `isDebuggable = true`, если их ещё нет.
      - Добавляет
        `signingConfig = signingConfigs.getByName("release")`, если строки нет.
    - **Важно**: строки
      `isMinifyEnabled`, `isShrinkResources`, `isDebuggable` и
      `signingConfig = signingConfigs.getByName("release")` считаются
      пользовательскими настройками и **никогда не удаляются** при очистке.
- **`proguard-rules.pro`**
  - Создаётся при отсутствии и заполняется стандартным набором правил для
    Huawei SDK и Flutter.
  - Если файл уже есть — HMS‑правила только добавляются при их отсутствии.
- **`AndroidManifest.xml`**
  - Добавляет:
    - `<queries>` с intent для `com.huawei.hms.core.aidlservice` (или дополняет
      существующий `<queries>`).
    - `meta-data` и `receiver`‑ы, необходимые для Huawei Push и локальных
      уведомлений.
  - Работает построчно, не ломая структуру XML и не удаляя чужие элементы.

Все изменения сопровождаются детальными лог‑сообщениями (выводятся в консоль).

### Что делает `cleanup`

Из корня Flutter‑проекта:

```bash
dart run hms_services:cleanup
```

Скрипт:

- Находит те же файлы, что и `setup`.
- Удаляет **только** те строки и блоки, которые он сам добавлял:
  - Плагины/репозитории HMS.
  - Подключение `proguard-rules.pro` в `release`.
  - Плагин `com.huawei.agconnect`.
  - Зависимость `installreferrer:2.2`.
  - HMS‑интенты, `meta-data` и `receiver`‑ы в `AndroidManifest.xml`.
  - HMS‑правила в `proguard-rules.pro`.
- Если `proguard-rules.pro` после очистки оказывается пустым — файл удаляется.
- Блоки (`plugins {}`, `dependencies {}`, `<queries>`) удаляются целиком только
  если после очистки внутри них не осталось ничего, кроме HMS‑строк.
- **Никогда не трогает**:
  - `isMinifyEnabled`, `isShrinkResources`, `isDebuggable`.
  - `signingConfig = signingConfigs.getByName("release")`.

---

## Messaging‑адаптер (Huawei Push)

Адаптер расположен в `lib/adapters/messaging/messaging.dart` и предоставляет
высокоуровневый API поверх `huawei_push`.

### Основной класс: `Messaging`

```dart
import 'package:hms_services/hms_services.dart';

Future<void> initHmsMessaging() async {
  final result = await HmsServices.instance.init(
    onPushBlocked: () {
      // Пользователь окончательно запретил пуши
      // Можно показать экран с инструкцией или отправить аналитику
    },
  );

  if (!result.success) {
    // Обработка ошибок инициализации
    for (final error in result.allErrors) {
      // Логика обработки
    }
  }

  final token = await HmsServices.instance.messaging.token;
  // Используйте token для регистрации на бэкенде
}
```

### Поведение и разрешения

`Messaging.init()`:

1. Инициализирует внутренний `Storage` (Hive‑бокс для сообщений и метаданных).
2. Вызывает приватный `_requestPermission()`:
   - `await Permission.notification.request();`
3. Проверяет в хранилище ключ
   `MessagingStorageKeys.firstPushRequestPermission`:
   - Если `null` – это **первый запрос**, сохраняется
     `{'value': false}` без вызова колбека.
   - Если не `null` – это **не первый запрос**, читается
     `Permission.notification.status`.  
     При значении `PermissionStatus.denied` вызывается
     `_onPushBlockedCallback` (колбек, переданный через
     `HmsServices.init(onPushBlocked: ...)`).
4. Загружает сохранённые сообщения из Hive.
5. Проверяет и логирует статус уведомлений:
   - `final status = await Permission.notification.status;`
   - Внутренний стрим `_onNotificationStatusChanged` публикует `true/false`
     (разрешены ли уведомления).
6. Получает токен через Huawei Push:
   - `Push.getToken('');`
   - Подписка на `Push.getTokenStream` заполняет `Completer<String>`:
     `Messaging.token`.
7. Обрабатывает начальное сообщение:
   - `final message = await Push.getInitialNotification();`
8. Настраивает слушатели (при необходимости).

### Основные API

- **Получение токена**

  ```dart
  final token = await Messaging.instance.token;
  ```

- **Поток входящих сообщений**

  ```dart
  Messaging.instance.onMessageReceived.listen((rawMessage) {
    // rawMessage: Map<Object?, Object?> из Huawei Push
  });
  ```

- **Доступ к сохранённым сообщениям**

  ```dart
  final messages = Messaging.instance.messages;
  ```

- **Статус уведомлений (стрим `bool`)**

  ```dart
  Messaging.instance.onNotificationStatusChanged.listen((isGranted) {
    // true, если Permission.notification.status == granted
  });
  ```

- **Колбек блокировки пушей**

  ```dart
  HmsServices.instance.init(
    onPushBlocked: () {
      // Пользователь окончательно запретил уведомления
    },
  );
  ```

- **Работа с последним открытым пушем**

  Адаптер хранит:

  - время последнего открытия пуша,
  - ID последнего сообщения,
  - флаг «просмотрен/не просмотрен».

  Доступны методы:

  ```dart
  // Было ли приложение открыто через пуш
  final opened = await Messaging.instance.wasAppOpenedByPush();

  // Просмотрен ли последний открытый пуш
  final viewed = await Messaging.instance.isLastOpenedPushViewed();

  // Отметить последний открытый пуш как просмотренный
  await Messaging.instance.markLastOpenedPushAsViewed();

  // Было ли открытие через пуш и он уже просмотрен
  final openedAndViewed =
      await Messaging.instance.wasAppOpenedByPushAndViewed();

  // В пределах ли 24 часов с момента открытия
  final within24h =
      await Messaging.instance.isWithin24HoursFromPushOpen();

  // И в пределах 24 часов, и просмотрен ли
  final within24hAndViewed =
      await Messaging.instance.isWithin24HoursFromPushOpenAndViewed();

  // Получить последний открытый пуш в пределах 24 часов
  final lastMessage =
      await Messaging.instance.getLastOpenedPushWithin24Hours();
  ```

---

## Ads‑адаптер (Huawei Ads)

Адаптер расположен в `lib/adapters/ads/ads.dart` и оборачивает работу с
`huawei_ads` для получения рекламного идентификатора.

### Основной класс: `Ads`

```dart
import 'package:hms_services/hms_services.dart';

Future<void> initHmsAds() async {
  final result = await HmsServices.instance.init();

  if (!result.success) {
    // Обработка ошибок инициализации
    for (final error in result.allErrors) {
      // Логика обработки
    }
  }

  final advertisingId = await HmsServices.instance.ads.advertisingId;
}
```

### Поведение

- При `Ads.init()`:
  - один раз запрашивается рекламный ID через
    `AdvertisingIdClient.getAdvertisingIdInfo()`;
  - результат кэшируется во внутреннем `Completer<String>`;
  - при ошибке возвращается `Consts.notAvailable`.
- Повторные вызовы `init()` не выполняют повторный запрос, а просто возвращают.

### Основные API

- **Получение рекламного ID**

  ```dart
  final advertisingId = await Ads.instance.advertisingId;
  ```

---

## Главный фасад: `HmsServices`

Класс `HmsServices` повторяет архитектуру `GmsServices` из GMS‑плагина и
предоставляет единую точку входа.

```dart
import 'package:hms_services/hms_services.dart';

Future<void> initHms() async {
  final result = await HmsServices.instance.init(
    onPushBlocked: () {
      // Пользователь запретил уведомления
    },
  );

  if (!result.success) {
    // Обработка ошибок инициализации
    for (final error in result.allErrors) {
      // Логика обработки
    }
  }

  final ads = HmsServices.instance.ads;
  final advertisingId = await ads.advertisingId;

  final messaging = HmsServices.instance.messaging;
  final token = await messaging.token;
}
```

### `HmsServicesInitResult`

- `bool success` – общий успех инициализации (все сервисы инициализированы).
- `bool ads` – успешно ли инициализирован Ads.
- `bool messaging` – успешно ли инициализирован Messaging.
- `List<String>? errors` – список ошибок по сервисам.
- `List<String> get allErrors` – удобный доступ ко всем ошибкам.

---

## Логирование

Все внутренние операции используют `HmsLogger` (`lib/src/logger.dart`):

- В debug‑режиме логи выводятся в консоль с префиксом `[hms_services]` и
  цветами по уровням.
- В release‑режиме логи выключены.

Можно использовать `HmsLogger` и в своём коде:

```dart
import 'package:hms_services/src/logger.dart';

HmsLogger.debug('Моё сообщение');
HmsLogger.error('Ошибка', error: e, stackTrace: st);
```

---

## Ограничения и заметки

- Плагин ориентирован на Android и работу с Huawei Push/Ads.
- Скрипты `setup/cleanup` должны запускаться из корня Flutter‑проекта.
- При ручном редактировании Gradle/Manifest старайтесь не дублировать строки,
  которые добавляет `setup` – скрипт и так аккуратно проверяет наличие строк
  перед вставкой.

Если поведение скриптов или адаптера нужно изменить под ваш пайплайн, основная
логика находится в `lib/src/setup_helper.dart` и
`lib/adapters/messaging/messaging.dart`.