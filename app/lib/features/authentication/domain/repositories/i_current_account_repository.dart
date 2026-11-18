import '../entities/guardian_account.dart';

/// Conta do responsavel com o painel aberto, para as funcionalidades que mostram ou alteram
/// dados da conta (configuracoes, preferencias de notificacao).
///
/// E uma visao estreita da sessao: quem so precisa da conta nao enxerga as operacoes de
/// abrir, bloquear e encerrar a sessao.
abstract interface class ICurrentAccountRepository {
  /// Conta atual, ou nulo quando o painel nao esta aberto.
  GuardianAccount? get currentAccount;

  /// Conta atual seguida das mudancas.
  Stream<GuardianAccount?> watchAccount();

  /// Troca a conta em memoria depois de uma alteracao aceita pelo servidor.
  void replaceAccount(GuardianAccount account);
}
