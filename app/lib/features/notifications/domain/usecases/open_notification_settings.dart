import '../services/i_notification_permission_service.dart';

/// Abre as configuracoes de notificacao do app no sistema (depois de uma recusa o sistema
/// nao mostra mais o pedido).
class OpenNotificationSettings {
  const OpenNotificationSettings(this._permission);

  final INotificationPermissionService _permission;

  Future<void> call() => _permission.openSettings();
}
