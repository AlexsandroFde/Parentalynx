import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../domain/services/i_notification_permission_service.dart';

/// Permissao de notificacoes pela ponte nativa ([DeviceApi]).
class NativeNotificationPermissionService implements INotificationPermissionService {
  const NativeNotificationPermissionService(this._api);

  final DeviceApi _api;

  @override
  Future<bool> isAllowed() async {
    // Sem resposta da ponte, assume permitido para nao insistir com a pessoa.
    final PermissionSnapshot? snapshot = await callNativeOr<PermissionSnapshot?>(
      _api.getPermissions,
      null,
    );
    return snapshot?.notifications ?? true;
  }

  @override
  Future<bool> request() => callNativeOr<bool>(_api.requestNotificationPermission, false);

  @override
  Future<void> openSettings() => callNativeOr<void>(_api.openNotificationSettings, null);
}
