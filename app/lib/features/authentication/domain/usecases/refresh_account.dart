import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/guardian_session.dart';
import '../repositories/i_auth_repository.dart';
import '../repositories/i_current_account_repository.dart';

/// Recarrega a conta do servidor. Sem conexao, a conta em memoria continua valendo.
class RefreshAccount {
  const RefreshAccount({required this._auth, required this._account});

  final IAuthRepository _auth;
  final ICurrentAccountRepository _account;

  Future<Result<GuardianProfile>> call() async {
    if (_account.currentAccount == null) {
      return const Err<GuardianProfile>(CancelledFailure('O painel não está aberto.'));
    }
    final Result<GuardianProfile> result = await _auth.fetchProfile();
    if (result case Ok<GuardianProfile>(:final GuardianProfile value)) {
      if (_account.currentAccount != null) {
        _account.replaceAccount(value.account);
      }
    }
    return result;
  }
}
