import '../../../../core/result/result.dart';
import '../entities/permission_step.dart';
import '../services/i_device_management_service.dart';
import '../services/i_platform_permission_service.dart';

/// Abre a tela do sistema (ou o dialogo) em que a permissao escolhida e concedida.
class OpenPermissionSettings {
  const OpenPermissionSettings({required this._permissions, required this._management});

  final IPlatformPermissionService _permissions;
  final IDeviceManagementService _management;

  Future<Result<PermissionActionResult>> call(PermissionKind kind) async {
    switch (kind) {
      case PermissionKind.usageAccess:
        return _opened(_permissions.openUsageAccessSettings());
      case PermissionKind.accessibility:
        return _opened(_permissions.openAccessibilitySettings());
      case PermissionKind.notifications:
        return _requestNotifications();
      case PermissionKind.batteryOptimization:
        return _opened(_permissions.requestIgnoreBatteryOptimizations());
      case PermissionKind.overlay:
        return _opened(_permissions.openOverlaySettings());
      case PermissionKind.exactAlarms:
        return _opened(_permissions.openExactAlarmSettings());
      case PermissionKind.deviceAdmin:
        return _opened(_management.requestDeviceAdmin());
      case PermissionKind.autostart:
        return _openAutostart();
    }
  }

  Future<Result<PermissionActionResult>> _requestNotifications() async {
    final Result<bool> granted = await _permissions.requestNotificationPermission();
    return switch (granted) {
      Ok<bool>(value: true) => const Ok<PermissionActionResult>(PermissionActionResult.granted),
      // Depois de uma recusa o sistema nao mostra mais o dialogo: abre as configuracoes.
      Ok<bool>() => _opened(_permissions.openNotificationSettings()),
      Err<bool>(:final failure) => Err<PermissionActionResult>(failure),
    };
  }

  Future<Result<PermissionActionResult>> _openAutostart() async {
    final Result<bool> opened = await _permissions.openManufacturerAutostartSettings();
    return switch (opened) {
      Ok<bool>(value: true) => const Ok<PermissionActionResult>(PermissionActionResult.opened),
      // Sem tela conhecida para o fabricante: as informacoes do app tem o caminho.
      Ok<bool>() => (await _permissions.openAppDetailsSettings()).map(
        (void _) => PermissionActionResult.fallbackToAppDetails,
      ),
      Err<bool>(:final failure) => Err<PermissionActionResult>(failure),
    };
  }

  static Future<Result<PermissionActionResult>> _opened(Future<Result<void>> open) async {
    return (await open).map((void _) => PermissionActionResult.opened);
  }
}
