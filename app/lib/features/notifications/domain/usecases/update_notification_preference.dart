import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/repositories/i_current_account_repository.dart';
import '../entities/alert_type.dart';
import '../entities/notification_preferences.dart';
import '../repositories/i_alerts_repository.dart';

/// Liga ou desliga a notificacao de um tipo de alerta.
///
/// A mudanca aparece na hora (a conta em memoria e atualizada antes do envio) e e desfeita se
/// o servidor recusar. Envia sempre o mapa completo, com todos os tipos conhecidos.
class UpdateNotificationPreference {
  const UpdateNotificationPreference({required this._alerts, required this._account});

  final IAlertsRepository _alerts;
  final ICurrentAccountRepository _account;

  Future<Result<Map<String, bool>>> call(AlertType type, {required bool enabled}) async {
    final GuardianAccount? account = _account.currentAccount;
    if (account == null) {
      return const Err<Map<String, bool>>(CancelledFailure('O painel não está aberto.'));
    }
    final Map<String, bool> previous = account.notificationPrefs;
    final Map<String, bool> next = NotificationPreferences(previous)
        .withType(type, enabled: enabled)
        .byType;
    _account.replaceAccount(account.copyWith(notificationPrefs: next));

    final Result<Map<String, bool>> result = await _alerts.updateNotificationPrefs(next);
    final GuardianAccount? current = _account.currentAccount;
    if (current != null) {
      _account.replaceAccount(current.copyWith(notificationPrefs: result.valueOrNull ?? previous));
    }
    return result;
  }
}
