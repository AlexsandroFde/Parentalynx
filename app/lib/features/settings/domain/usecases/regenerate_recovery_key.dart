import '../../../../core/result/result.dart';
import '../repositories/i_account_management_repository.dart';

/// Gera uma nova chave de recuperacao, confirmada pela senha administrativa. A chave anterior
/// deixa de valer.
class RegenerateRecoveryKey {
  const RegenerateRecoveryKey(this._repository);

  final IAccountManagementRepository _repository;

  Future<Result<String>> call(String password) => _repository.regenerateRecoveryKey(password);
}
