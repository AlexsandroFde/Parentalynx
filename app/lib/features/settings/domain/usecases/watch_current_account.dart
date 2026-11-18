import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/repositories/i_current_account_repository.dart';

/// Conta do responsavel com o painel aberto, seguida das mudancas.
class WatchCurrentAccount {
  const WatchCurrentAccount(this._account);

  final ICurrentAccountRepository _account;

  /// Conta atual, ou nulo quando o painel nao esta aberto.
  GuardianAccount? get current => _account.currentAccount;

  /// Conta atual seguida das mudancas.
  Stream<GuardianAccount?> call() => _account.watchAccount();
}
