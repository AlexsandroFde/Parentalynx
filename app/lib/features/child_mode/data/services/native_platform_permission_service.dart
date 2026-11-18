import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/permission_facts.dart';
import '../../domain/services/i_platform_permission_service.dart';
import '../mappers/agent_status_mapper.dart';

/// Permissoes especiais e telas do sistema pela ponte nativa ([DeviceApi]).
class NativePlatformPermissionService implements IPlatformPermissionService {
  const NativePlatformPermissionService(this._api);

  final DeviceApi _api;

  @override
  Future<Result<PermissionFacts>> permissions() async {
    final Result<PermissionSnapshot> snapshot = await callNative<PermissionSnapshot>(
      _api.getPermissions,
    );
    return snapshot.map(AgentStatusMapper.permissions);
  }

  @override
  Future<Result<void>> openUsageAccessSettings() => callNative<void>(_api.openUsageAccessSettings);

  @override
  Future<Result<void>> openAccessibilitySettings() {
    return callNative<void>(_api.openAccessibilitySettings);
  }

  @override
  Future<Result<void>> openOverlaySettings() => callNative<void>(_api.openOverlaySettings);

  @override
  Future<Result<void>> requestIgnoreBatteryOptimizations() {
    return callNative<void>(_api.requestIgnoreBatteryOptimizations);
  }

  @override
  Future<Result<void>> openExactAlarmSettings() => callNative<void>(_api.openExactAlarmSettings);

  @override
  Future<Result<void>> openNotificationSettings() {
    return callNative<void>(_api.openNotificationSettings);
  }

  @override
  Future<Result<bool>> requestNotificationPermission() {
    return callNative<bool>(_api.requestNotificationPermission);
  }

  @override
  Future<Result<void>> openAppDetailsSettings() => callNative<void>(_api.openAppDetailsSettings);

  @override
  Future<Result<bool>> openManufacturerAutostartSettings() {
    return callNative<bool>(_api.openManufacturerAutostartSettings);
  }
}
