import '../entities/app_lock_timeout.dart';
import '../repositories/i_app_lock_repository.dart';

/// Le e grava o tempo de bloqueio do painel escolhido pelo responsavel.
class AppLockPreference {
  const AppLockPreference(this._repository);

  final IAppLockRepository _repository;

  Future<AppLockTimeout> read() => _repository.read();

  Future<void> write(AppLockTimeout timeout) => _repository.write(timeout);
}
