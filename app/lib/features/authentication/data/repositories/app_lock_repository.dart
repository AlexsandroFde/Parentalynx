import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_preferences.dart';
import '../../domain/entities/app_lock_timeout.dart';
import '../../domain/repositories/i_app_lock_repository.dart';

/// Tempo de bloqueio do painel nas preferencias locais.
///
/// Guarda o valor lido em memoria: o bloqueio por inatividade consulta a preferencia a cada
/// volta do app e nao precisa ir ao disco toda vez.
class AppLockRepository implements IAppLockRepository {
  AppLockRepository(this._preferences);

  final LocalPreferences _preferences;
  AppLockTimeout? _cached;

  @override
  Future<AppLockTimeout> read() async {
    final AppLockTimeout? cached = _cached;
    if (cached != null) {
      return cached;
    }
    final int? stored = await _preferences.readInt(LocalPrefKeys.appLockTimeoutSeconds);
    final AppLockTimeout value = stored == null
        ? AppLockTimeout.standard
        : AppLockTimeout.fromSeconds(stored);
    _cached = value;
    return value;
  }

  @override
  Future<void> write(AppLockTimeout timeout) async {
    _cached = timeout;
    await _preferences.writeInt(LocalPrefKeys.appLockTimeoutSeconds, timeout.seconds);
  }
}
