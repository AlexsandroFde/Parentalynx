/// Permissao do sistema para o app mostrar notificacoes neste aparelho.
abstract interface class INotificationPermissionService {
  /// Verdadeiro quando o sistema permite as notificacoes. Sem resposta do sistema, assume
  /// que sim, para nao insistir com a pessoa.
  Future<bool> isAllowed();

  /// Pede a permissao ao sistema. Verdadeiro se ficou concedida.
  Future<bool> request();

  /// Abre as configuracoes de notificacao do app.
  Future<void> openSettings();
}
