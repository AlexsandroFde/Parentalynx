import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/repositories/i_current_account_repository.dart';
import '../entities/notification_preferences.dart';

/// Preferencias de notificacao da conta com o painel aberto, seguidas das mudancas. Nulo
/// quando o painel nao esta aberto.
class WatchNotificationPreferences {
  const WatchNotificationPreferences(this._account);

  final ICurrentAccountRepository _account;

  Stream<NotificationPreferences?> call() {
    return _account.watchAccount().map(_preferencesOf).distinct();
  }

  static NotificationPreferences? _preferencesOf(GuardianAccount? account) {
    return account == null ? null : NotificationPreferences(account.notificationPrefs);
  }
}
