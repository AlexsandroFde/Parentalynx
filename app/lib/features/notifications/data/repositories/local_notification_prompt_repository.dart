import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_preferences.dart';
import '../../domain/repositories/i_notification_prompt_repository.dart';

/// Marca do pedido de notificacoes nas preferencias locais.
class LocalNotificationPromptRepository implements INotificationPromptRepository {
  const LocalNotificationPromptRepository(this._preferences);

  final LocalPreferences _preferences;

  @override
  Future<bool> wasPrompted() async {
    return await _preferences.readBool(LocalPrefKeys.notificationsPrompted) ?? false;
  }

  @override
  Future<void> markPrompted() {
    return _preferences.writeBool(LocalPrefKeys.notificationsPrompted, true);
  }
}
