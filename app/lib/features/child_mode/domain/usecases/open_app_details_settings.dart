import '../../../../core/result/result.dart';
import '../services/i_platform_permission_service.dart';

/// Abre a tela de informacoes do app, onde se liberam as "configuracoes restritas".
class OpenAppDetailsSettings {
  const OpenAppDetailsSettings(this._permissions);

  final IPlatformPermissionService _permissions;

  Future<Result<void>> call() => _permissions.openAppDetailsSettings();
}
