import '../../../../core/result/result.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../../../authentication/domain/usecases/end_session.dart';
import '../repositories/i_account_management_repository.dart';

/// Apaga a conta e todos os dados. Com a exclusao aceita pelo servidor, encerra a sessao
/// deste aparelho com o aviso de conta excluida.
class DeleteAccount {
  const DeleteAccount({required this._repository, required this._endSession});

  final IAccountManagementRepository _repository;
  final EndSession _endSession;

  Future<Result<void>> call(String password) async {
    final Result<void> result = await _repository.deleteAccount(password);
    if (result is Ok<void>) {
      await _endSession(SessionEndReason.accountDeleted);
    }
    return result;
  }
}
