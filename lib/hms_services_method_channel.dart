import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hms_services_platform_interface.dart';

/// An implementation of [HmsServicesPlatform] that uses method channels.
class MethodChannelHmsServices extends HmsServicesPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hms_services');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
