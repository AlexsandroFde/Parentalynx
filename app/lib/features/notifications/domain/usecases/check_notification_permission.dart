import '../services/i_notification_permission_service.dart';

/// O sistema permite que o app mostre notificacoes?
class CheckNotificationPermission {
  const CheckNotificationPermission(this._permission);

  final INotificationPermissionService _permission;

  Future<bool> call() => _permission.isAllowed();
}
