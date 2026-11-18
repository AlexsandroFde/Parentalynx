import 'package:equatable/equatable.dart';

/// Situacao de um pedido de tempo adicional.
enum TimeRequestStatus {
  pending('Aguardando'),
  approved('Aprovado'),
  denied('Negado'),
  expired('Expirado');

  const TimeRequestStatus(this.label);

  final String label;
}

/// Pedido de tempo adicional feito pela crianca, visto pelo responsavel (protocolo, secao 6).
final class TimeRequest extends Equatable {
  const TimeRequest({
    required this.id,
    required this.deviceId,
    required this.childName,
    required this.createdAt,
    required this.status,
    this.minutes,
    this.message,
    this.grantedMinutes,
    this.resolvedAt,
  });

  /// Maior tempo que pode ser concedido de uma vez: 12 horas.
  static const int maxGrantMinutes = 720;

  /// Tempo sugerido quando a crianca nao pediu um valor (ou pediu fora do permitido).
  static const int defaultGrantMinutes = 30;

  final String id;
  final String deviceId;
  final String childName;
  final int createdAt;

  /// Minutos pedidos. Nulo quando a crianca nao escolheu um valor.
  final int? minutes;
  final String? message;
  final TimeRequestStatus status;
  final int? grantedMinutes;
  final int? resolvedAt;

  bool get isPending => status == TimeRequestStatus.pending;

  /// Minutos sugeridos ao aprovar: o que a crianca pediu, quando esta entre 1 minuto e
  /// [maxGrantMinutes]; senao [defaultGrantMinutes].
  int get suggestedGrantMinutes {
    final int? requested = minutes;
    return requested != null && requested >= 1 && requested <= maxGrantMinutes
        ? requested
        : defaultGrantMinutes;
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    deviceId,
    childName,
    createdAt,
    status,
    minutes,
    message,
    grantedMinutes,
    resolvedAt,
  ];
}
