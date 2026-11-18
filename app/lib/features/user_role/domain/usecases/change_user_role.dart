import '../../../../core/result/result.dart';
import '../entities/user_role.dart';
import '../repositories/i_user_role_repository.dart';

/// Troca o perfil do app neste aparelho (escolha nas boas-vindas, volta a escolha de modo).
class ChangeUserRole {
  const ChangeUserRole(this._repository);

  final IUserRoleRepository _repository;

  Future<Result<void>> call(UserRole role) async {
    if (_repository.current == role) {
      return okVoid;
    }
    return _repository.change(role);
  }
}
