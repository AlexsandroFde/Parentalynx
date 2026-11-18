/// Tipos de alerta do protocolo, com o texto das preferencias de notificacao.
///
/// O [code] e o identificador do protocolo e a chave das preferencias de notificacao.
enum AlertType {
  limitReached('limit_reached', 'Limite diário atingido', 'Quando o tempo do dia acaba.'),
  lowTime('low_time', 'Pouco tempo restante', 'Quando o tempo do dia está perto de acabar.'),
  blockedAppAttempt(
    'blocked_app_attempt',
    'Tentativa de abrir app bloqueado',
    'No máximo um aviso por aplicativo a cada 10 minutos.',
  ),
  timeRequest('time_request', 'Pedido de tempo adicional', 'Quando a criança pede mais tempo.'),
  syncStale(
    'sync_stale',
    'Aparelho sem sincronizar',
    'Quando o aparelho fica um tempo sem falar com o servidor.',
  ),
  deviceOffline(
    'device_offline',
    'Aparelho offline por muito tempo',
    'Pode indicar aparelho desligado, sem internet ou app removido.',
  ),
  permissionChanged(
    'permission_changed',
    'Permissão alterada',
    'Quando uma permissão necessária ao controle é desativada ou reativada.',
  ),
  enforcementFailure(
    'enforcement_failure',
    'Falha na aplicação das regras',
    'Quando o aparelho não consegue aplicar uma regra.',
  ),
  securityEvent(
    'security_event',
    'Evento de segurança',
    'Relógio alterado, senha errada no aparelho, liberação local, desvinculação.',
  ),
  newAppInstalled('new_app_installed', 'Novo app instalado', 'Quando um aplicativo é instalado.'),
  policyChanged(
    'policy_changed',
    'Alteração de configuração',
    'Quando as regras são alteradas por outro aparelho da conta.',
  ),
  deviceLinked(
    'device_linked',
    'Vinculação de aparelhos',
    'Pedidos de vínculo, aprovações e revogações.',
  );

  const AlertType(this.code, this.label, this.description);

  final String code;
  final String label;
  final String description;

  static AlertType? fromCode(String code) {
    for (final AlertType type in values) {
      if (type.code == code) {
        return type;
      }
    }
    return null;
  }
}
