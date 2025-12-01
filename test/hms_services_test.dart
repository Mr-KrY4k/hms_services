import 'package:flutter_test/flutter_test.dart';
import 'package:hms_services/hms_services.dart';
import 'package:hms_services/hms_services_platform_interface.dart';
import 'package:hms_services/hms_services_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHmsServicesPlatform
    with MockPlatformInterfaceMixin
    implements HmsServicesPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final HmsServicesPlatform initialPlatform = HmsServicesPlatform.instance;

  test('$MethodChannelHmsServices is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHmsServices>());
  });

  test('getPlatformVersion', () async {
    HmsServices hmsServicesPlugin = HmsServices();
    MockHmsServicesPlatform fakePlatform = MockHmsServicesPlatform();
    HmsServicesPlatform.instance = fakePlatform;

    expect(await hmsServicesPlugin.getPlatformVersion(), '42');
  });
}
