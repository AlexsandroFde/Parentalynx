import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/repositories/i_current_account_repository.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_account_management_repository.dart';
import '../services/account_rules.dart';

/// (E) Troca o nome de exibicao do responsavel. Com a troca aceita pelo servidor, a conta em
/// memoria passa a ter o nome novo.
class UpdateDisplayName {
  const UpdateDisplayName({
    required this._repository,
    required this._account,
    required this._runElevated,
  });

  final IAccountManagementRepository _repository;
  final ICurrentAccountRepository _account;
  final RunElevated _runElevated;

  Future<Result<GuardianAccount>> call(String name) async {
    final String clean = name.trim();
    final String? error = AccountRules.displayNameError(clean);
    if (error != null) {
      return Err<GuardianAccount>(ValidationFailure(error));
    }
    final Result<GuardianAccount> result = await _runElevated<GuardianAccount>(
      () => _repository.updateProfile(displayName: clean),
    );
    if (result case Ok<GuardianAccount>(:final GuardianAccount value)) {
      _account.replaceAccount(value);
    }
    return result;
  }
}
