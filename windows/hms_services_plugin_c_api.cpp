#include "include/hms_services/hms_services_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "hms_services_plugin.h"

void HmsServicesPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  hms_services::HmsServicesPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
