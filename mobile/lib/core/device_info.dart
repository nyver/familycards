import 'dart:io' show Platform;

/// A best-effort default device name/platform pair for registering with
/// the server. The user is not required to customize this for the app to
/// work; a nicer name can be added in settings later.
class DeviceIdentity {
  final String name;
  final String platform;
  const DeviceIdentity({required this.name, required this.platform});
}

DeviceIdentity currentDeviceIdentity() {
  if (Platform.isAndroid) {
    return const DeviceIdentity(name: 'Android Device', platform: 'android');
  }
  if (Platform.isIOS) {
    return const DeviceIdentity(name: 'iPhone', platform: 'ios');
  }
  return const DeviceIdentity(name: 'Unknown Device', platform: 'other');
}
