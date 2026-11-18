import '../entities/user_role.dart';
import '../repositories/i_user_role_repository.dart';

/// Perfil atual seguido das trocas, para quem decide a area do app (roteador).
class WatchUserRole {
  const WatchUserRole(this._repository);

  final IUserRoleRepository _repository;

  UserRole get current => _repository.current;

  Stream<UserRole> call() => _repository.watch();
}
