import '../entities/guardian_session.dart';

/// Sessao do responsavel neste aparelho: credenciais gravadas e situacao atual (sem sessao,
/// bloqueada ou aberta).
///
/// E a fonte unica de verdade da sessao. Os casos de uso alteram a situacao; quem precisa
/// reagir (roteador, painel, alertas em segundo plano) observa [watch].
abstract interface class ISessionRepository {
  GuardianSessionState get current;

  /// Situacao atual seguida das mudancas.
  Stream<GuardianSessionState> watch();

  /// Grava as credenciais da sessao recem-criada e abre o painel.
  Future<void> open(AuthenticatedSession session);

  /// Abre o painel bloqueado depois de a senha ser confirmada.
  void unlock(GuardianProfile profile);

  /// Bloqueia o painel, mantendo a sessao.
  void lock();

  /// A chave de recuperacao foi guardada e nao precisa mais ser mostrada.
  void clearPendingRecoveryKey();

  /// Apaga as credenciais deste aparelho e encerra a sessao local.
  Future<void> close(SessionEndReason reason);

  /// E-mail da ultima conta usada neste aparelho, para a tela de bloqueio e a recuperacao.
  Future<String?> storedEmail();

  /// Avisos de que o servidor recusou a sessao atual (vencida ou encerrada em outro lugar).
  Stream<void> get rejections;
}
