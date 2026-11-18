import '../services/i_notification_permission_service.dart';

/// Pede ao sistema a permissao de notificacoes. Verdadeiro se ficou concedida.
class RequestNotificationPermission {
  const RequestNotificationPermission(this._permission);

  final INotificationPermissionService _permission;

  Future<bool> call() => _permission.request();
}
