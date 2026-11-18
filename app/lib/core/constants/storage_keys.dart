/// Chaves do armazenamento seguro usadas pelo lado Dart.
///
/// O prefixo `agent.` e reservado ao agente nativo e nao pode ser lido daqui.
abstract final class StorageKeys {
  static const String serverUrl = 'config.server_url';

  /// Lida tambem pelo worker nativo de alertas. Nao renomear sem alterar o Kotlin.
  static const String guardianSessionToken = 'guardian.session_token';
  static const String guardianSessionId = 'guardian.session_id';
  static const String guardianEmail = 'guardian.email';

  /// Pedido de vinculo em andamento no aparelho da crianca.
  static const String childPendingClaim = 'child.pending_claim';
}

/// Chaves das preferencias locais nao sensiveis.
abstract final class LocalPrefKeys {
  static const String appLockTimeoutSeconds = 'guardian.app_lock_timeout_seconds';
  static const String notificationsPrompted = 'guardian.notifications_prompted';
}
