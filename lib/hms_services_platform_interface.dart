import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hms_services_method_channel.dart';

abstract class HmsServicesPlatform extends PlatformInterface {
  /// Constructs a HmsServicesPlatform.
  HmsServicesPlatform() : super(token: _token);

  static final Object _token = Object();

  static HmsServicesPlatform _instance = MethodChannelHmsServices();

  /// The default instance of [HmsServicesPlatform] to use.
  ///
  /// Defaults to [MethodChannelHmsServices].
  static HmsServicesPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HmsServicesPlatform] when
  /// they register themselves.
  static set instance(HmsServicesPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
