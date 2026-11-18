/// Busca de alertas em segundo plano feita pelo lado nativo, com o app do responsavel
/// fechado (worker a cada 15 minutos).
///
/// E um reforco: se a ponte falhar, o painel continua com os alertas em tempo real. Por isso
/// nenhuma operacao devolve erro.
abstract interface class IAlertPollingService {
  /// Liga a busca para a sessao atual.
  Future<void> enable();

  /// Desliga a busca (sessao encerrada).
  Future<void> disable();

  /// Avisa que os alertas ate [alertId] ja foram vistos, para nao notificar de novo.
  Future<void> markSeen(int alertId);
}
