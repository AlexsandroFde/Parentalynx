import '../../../../core/result/result.dart';
import '../repositories/i_account_management_repository.dart';

/// Troca a senha administrativa. As outras sessoes da conta sao encerradas pelo servidor.
class ChangePassword {
  const ChangePassword(this._repository);

  final IAccountManagementRepository _repository;

  Future<Result<void>> call({required String currentPassword, required String newPassword}) {
    return _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }
}
