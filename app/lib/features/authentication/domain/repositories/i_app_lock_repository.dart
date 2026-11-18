import '../entities/app_lock_timeout.dart';

/// Preferencia local de bloqueio do painel.
abstract interface class IAppLockRepository {
  /// Tempo escolhido, ou o padrao quando nunca foi escolhido.
  Future<AppLockTimeout> read();

  Future<void> write(AppLockTimeout timeout);
}
