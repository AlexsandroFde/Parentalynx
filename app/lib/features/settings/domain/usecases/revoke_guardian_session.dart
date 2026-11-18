import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_account_management_repository.dart';

/// (E) Encerra a sessao de outro aparelho de responsavel.
class RevokeGuardianSession {
  const RevokeGuardianSession({required this._repository, required this._runElevated});

  final IAccountManagementRepository _repository;
  final RunElevated _runElevated;

  Future<Result<void>> call(String sessionId) {
    return _runElevated<void>(() => _repository.revokeSession(sessionId));
  }
}
