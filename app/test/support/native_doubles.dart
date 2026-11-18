import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';

class MockAppModeApi extends Mock implements AppModeApi {}

class MockDeviceApi extends Mock implements DeviceApi {}

class MockGuardianNativeApi extends Mock implements GuardianNativeApi {}

class MockChildAgentApi extends Mock implements ChildAgentApi {}

class MockBrowserApi extends Mock implements BrowserApi {}

class MockSecureStorageApi extends Mock implements SecureStorageApi {}

/// Dubles da ponte nativa com respostas padrao de um aparelho comum.
///
/// Cada teste pode trocar uma resposta com `when(...)` depois de criar os dubles.
class NativeDoubles {
  NativeDoubles({bool notificationsAllowed = true}) {
    registerFallbackValue(AppMode.unset);
    when(() => guardian.enableAlertPolling(any())).thenAnswer((_) async {});
    when(guardian.disableAlertPolling).thenAnswer((_) async {});
    when(() => guardian.setLastSeenAlertId(any())).thenAnswer((_) async {});
    when(guardian.getLastSeenAlertId).thenAnswer((_) async => 0);
    when(device.getDeviceInfo).thenAnswer((_) async => deviceInfo());
    when(device.getPermissions).thenAnswer(
      (_) async => PermissionSnapshot(
        usageAccess: false,
        accessibility: false,
        overlay: false,
        notifications: notificationsAllowed,
        batteryOptimizationIgnored: false,
        deviceAdmin: false,
        deviceOwner: false,
        exactAlarms: false,
        restrictedSettingsLikely: false,
      ),
    );
    when(device.requestNotificationPermission).thenAnswer((_) async => true);
    when(device.openNotificationSettings).thenAnswer((_) async {});
    when(mode.getMode).thenAnswer((_) async => AppMode.unset);
    when(mode.consumeLaunchAction).thenAnswer((_) async => null);
    when(() => mode.setMode(any())).thenAnswer((_) async {});
  }

  final MockGuardianNativeApi guardian = MockGuardianNativeApi();
  final MockDeviceApi device = MockDeviceApi();
  final MockAppModeApi mode = MockAppModeApi();
  final MockChildAgentApi agent = MockChildAgentApi();
  final MockBrowserApi browser = MockBrowserApi();

  static NativeDeviceInfo deviceInfo({
    String name = 'Galaxy da Maria',
    String manufacturer = 'samsung',
  }) {
    return NativeDeviceInfo(
      name: name,
      model: 'SM-A546',
      manufacturer: manufacturer,
      androidRelease: '15',
      sdkInt: 35,
      appVersion: '1.0.0',
      timezone: 'America/Fortaleza',
      hardwareId: 'abc',
    );
  }
}
