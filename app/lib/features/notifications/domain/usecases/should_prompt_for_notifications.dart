import '../repositories/i_notification_prompt_repository.dart';
import '../services/i_notification_permission_service.dart';

/// Decide se o painel deve explicar as notificacoes e pedir a permissao agora.
///
/// So na primeira vez que o painel abre neste aparelho, e so se a permissao ainda nao foi
/// dada. Depois disso a pessoa ativa pelo aviso da central de alertas ou das preferencias.
class ShouldPromptForNotifications {
  const ShouldPromptForNotifications({required this._prompts, required this._permission});

  final INotificationPromptRepository _prompts;
  final INotificationPermissionService _permission;

  Future<bool> call() async {
    if (await _prompts.wasPrompted()) {
      return false;
    }
    final bool allowed = await _permission.isAllowed();
    await _prompts.markPrompted();
    return !allowed;
  }
}
