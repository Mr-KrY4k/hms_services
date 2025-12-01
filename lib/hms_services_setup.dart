/// Публичный API для программной настройки и очистки Android проекта.
///
/// Этот модуль экспортирует функции setup и cleanup для удобного использования.
/// Вы можете импортировать этот модуль для доступа к обеим функциям.
library hms_services_setup;

export 'src/setup_helper.dart' show SetupResult;
export 'src/hms_services_setup.dart' show setupHmsServices;
export 'src/hms_services_cleanup.dart' show cleanupHmsServices;

