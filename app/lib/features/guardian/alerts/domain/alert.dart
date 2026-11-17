import '../../../../core/json/json_reader.dart';

/// Alerta para o responsavel (protocolo, secao 2.5). Titulo e texto vem prontos do servidor.
class GuardianAlert {
  const GuardianAlert({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.notify,
    required this.title,
    required this.body,
    this.deviceId,
    this.childName,
    this.readAt,
    this.data = const JsonMap.empty(),
  });

  factory GuardianAlert.fromJson(JsonMap json) {
    return GuardianAlert(
      id: json.integer('id'),
      type: json.strOrNull('type') ?? '',
      deviceId: json.strOrNull('deviceId'),
      childName: json.strOrNull('childName'),
      createdAt: json.intOr('createdAt', fallback: 0),
      readAt: json.intOrNull('readAt'),
      notify: json.boolOr('notify', fallback: true),
      title: json.strOrNull('title') ?? '',
      body: json.strOrNull('body') ?? '',
      data: json.objOrNull('data') ?? const JsonMap.empty(),
    );
  }

  final int id;

  /// Tipo do protocolo: `limit_reached`, `time_request`, `security_event`, ...
  final String type;
  final String? deviceId;
  final String? childName;
  final int createdAt;
  final int? readAt;

  /// Falso quando o tipo esta desligado nas preferencias: aparece na central, sem notificar.
  final bool notify;
  final String title;
  final String body;
  final JsonMap data;

  bool get isRead => readAt != null;

  GuardianAlert markedRead(int at) {
    return GuardianAlert(
      id: id,
      type: type,
      deviceId: deviceId,
      childName: childName,
      createdAt: createdAt,
      readAt: readAt ?? at,
      notify: notify,
      title: title,
      body: body,
      data: data,
    );
  }
}

/// Uma pagina da central de alertas.
class AlertsPage {
  const AlertsPage({required this.alerts, required this.latestId, required this.unread});

  factory AlertsPage.fromJson(JsonMap json) {
    return AlertsPage(
      alerts: json.objList('alerts').map(GuardianAlert.fromJson).toList(),
      latestId: json.intOr('latestId', fallback: 0),
      unread: json.intOr('unread', fallback: 0),
    );
  }

  final List<GuardianAlert> alerts;

  /// Maior identificador de alerta da conta.
  final int latestId;

  /// Quantidade de alertas nao lidos na conta.
  final int unread;
}

/// Tipos de alerta que o responsavel pode ligar e desligar, na ordem em que aparecem nas
/// preferencias.
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
