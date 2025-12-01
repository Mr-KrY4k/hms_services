
import 'hms_services_platform_interface.dart';

class HmsServices {
  Future<String?> getPlatformVersion() {
    return HmsServicesPlatform.instance.getPlatformVersion();
  }
}
