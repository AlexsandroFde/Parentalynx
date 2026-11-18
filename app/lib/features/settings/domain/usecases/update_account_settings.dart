import '../../../../core/result/result.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/repositories/i_current_account_repository.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_account_management_repository.dart';

/// (E) Grava os ajustes da conta (retencao e limiares dos alertas). Com a mudanca aceita pelo
/// servidor, a conta em memoria passa a ter os ajustes novos.
class UpdateAccountSettings {
  const UpdateAccountSettings({
    required this._repository,
    required this._account,
    required this._runElevated,
  });

  final IAccountManagementRepository _repository;
  final ICurrentAccountRepository _account;
  final RunElevated _runElevated;

  Future<Result<GuardianAccount>> call(GuardianSettings settings) async {
    final Result<GuardianAccount> result = await _runElevated<GuardianAccount>(
      () => _repository.updateProfile(settings: settings),
    );
    if (result case Ok<GuardianAccount>(:final GuardianAccount value)) {
      _account.replaceAccount(value);
    }
    return result;
  }
}
