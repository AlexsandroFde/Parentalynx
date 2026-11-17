import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_providers.dart';
import '../domain/child_models.dart';
import 'agent_mappers.dart';
import 'native_guard.dart';

/// Informacoes do aparelho, permissoes especiais e atalhos para as telas do sistema.
class ChildDeviceRepository {
  const ChildDeviceRepository(this._api);

  final DeviceApi _api;

  Future<DeviceIdentity> deviceInfo() async {
    return deviceIdentityFrom(await guardNative(_api.getDeviceInfo));
  }

  Future<PermissionFacts> permissions() async {
    return permissionFactsFrom(await guardNative(_api.getPermissions));
  }

  Future<void> openUsageAccessSettings() => guardNative(_api.openUsageAccessSettings);

  Future<void> openAccessibilitySettings() => guardNative(_api.openAccessibilitySettings);

  Future<void> openOverlaySettings() => guardNative(_api.openOverlaySettings);

  Future<void> requestIgnoreBatteryOptimizations() {
    return guardNative(_api.requestIgnoreBatteryOptimizations);
  }

  Future<void> openExactAlarmSettings() => guardNative(_api.openExactAlarmSettings);

  Future<void> openNotificationSettings() => guardNative(_api.openNotificationSettings);

  /// Tela de informacoes do app (configuracoes restritas, inicio automatico).
  Future<void> openAppDetailsSettings() => guardNative(_api.openAppDetailsSettings);

  /// Falso quando nao ha tela de inicio automatico conhecida para o fabricante.
  Future<bool> openManufacturerAutostartSettings() {
    return guardNative(_api.openManufacturerAutostartSettings);
  }

  /// Verdadeiro se a permissao de notificacoes ficou concedida.
  Future<bool> requestNotificationPermission() => guardNative(_api.requestNotificationPermission);

  Future<void> requestDeviceAdmin() => guardNative(_api.requestDeviceAdmin);

  /// Exige autenticacao do responsavel valida no lado nativo.
  Future<void> removeDeviceAdmin() => guardNative(_api.removeDeviceAdmin);

  /// Exige autenticacao do responsavel valida no lado nativo.
  Future<bool> releaseDeviceOwner() => guardNative(_api.releaseDeviceOwner);
}

final Provider<ChildDeviceRepository> childDeviceRepositoryProvider =
    Provider<ChildDeviceRepository>(
      (Ref ref) => ChildDeviceRepository(ref.watch(deviceApiProvider)),
    );
