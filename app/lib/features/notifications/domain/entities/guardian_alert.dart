import 'package:equatable/equatable.dart';

/// Alerta para o responsavel (protocolo, secao 2.5). Titulo e texto vem prontos do servidor.
final class GuardianAlert extends Equatable {
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
  });

  /// Identificador crescente: alertas mais novos tem identificador maior.
  final int id;

  /// Tipo do protocolo (`limit_reached`, `time_request`, ...).
  final String type;
  final String? deviceId;
  final String? childName;
  final int createdAt;
  final int? readAt;

  /// Falso quando o tipo esta desligado nas preferencias: o alerta aparece na central, mas
  /// nao gerou notificacao.
  final bool notify;
  final String title;
  final String body;

  bool get isRead => readAt != null;

  /// O mesmo alerta marcado como lido no instante [at] (ou mantendo a leitura anterior).
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
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    type,
    deviceId,
    childName,
    createdAt,
    readAt,
    notify,
    title,
    body,
  ];
}

/// Uma pagina da central de alertas, com a contagem de nao lidos da conta.
final class AlertsPage extends Equatable {
  const AlertsPage({required this.alerts, required this.latestId, required this.unread});

  /// Alertas do mais novo para o mais antigo.
  final List<GuardianAlert> alerts;

  /// Maior identificador de alerta da conta.
  final int latestId;

  /// Quantos alertas continuam nao lidos.
  final int unread;

  @override
  List<Object?> get props => <Object?>[alerts, latestId, unread];
}
