import 'package:equatable/equatable.dart';

/// Aviso em tempo real recebido do servidor (protocolo, secao 7).
///
/// O canal so avisa que algo mudou: quem recebe busca o estado atualizado pelas rotas HTTP,
/// entao perder um aviso nao causa inconsistencia.
sealed class RealtimeUpdate extends Equatable {
  const RealtimeUpdate();

  /// Aparelho a que o aviso se refere, quando ha um.
  String? get deviceId => null;

  /// Verdadeiro para avisos que mudam a lista ou o estado dos aparelhos.
  bool get affectsDevices => false;
}

/// O aparelho enviou um retrato novo (uso, bloqueio, permissoes).
final class DeviceStateChanged extends RealtimeUpdate {
  const DeviceStateChanged(this.deviceId);

  @override
  final String deviceId;

  @override
  bool get affectsDevices => true;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Um aparelho pediu vinculo com um codigo desta conta.
final class LinkRequested extends RealtimeUpdate {
  const LinkRequested(this.deviceId);

  @override
  final String deviceId;

  @override
  bool get affectsDevices => true;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Um pedido de vinculo foi aprovado ou recusado (em qualquer sessao da conta).
final class LinkResolved extends RealtimeUpdate {
  const LinkResolved({required this.deviceId, required this.status});

  @override
  final String deviceId;

  /// `approved` ou `rejected`.
  final String status;

  @override
  bool get affectsDevices => true;

  @override
  List<Object?> get props => <Object?>[deviceId, status];
}

/// O aparelho confirmou que aplicou uma versao da politica.
final class PolicyApplied extends RealtimeUpdate {
  const PolicyApplied({required this.deviceId, required this.version});

  @override
  final String deviceId;
  final int version;

  @override
  bool get affectsDevices => true;

  @override
  List<Object?> get props => <Object?>[deviceId, version];
}

/// A crianca pediu mais tempo.
final class TimeRequestReceived extends RealtimeUpdate {
  const TimeRequestReceived({required this.deviceId, required this.requestId});

  @override
  final String deviceId;
  final String requestId;

  @override
  bool get affectsDevices => true;

  @override
  List<Object?> get props => <Object?>[deviceId, requestId];
}

/// Um alerta novo foi gerado para a conta.
final class AlertRaised extends RealtimeUpdate {
  const AlertRaised(this.alert);

  final RealtimeAlert alert;

  @override
  String? get deviceId => alert.deviceId;

  @override
  List<Object?> get props => <Object?>[alert];
}

/// Alerta como chega pelo canal em tempo real. A funcionalidade de notificacoes converte no
/// seu proprio modelo de alerta.
final class RealtimeAlert extends Equatable {
  const RealtimeAlert({
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

  final int id;
  final String type;
  final int createdAt;
  final bool notify;
  final String title;
  final String body;
  final String? deviceId;
  final String? childName;
  final int? readAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    type,
    createdAt,
    notify,
    title,
    body,
    deviceId,
    childName,
    readAt,
  ];
}
