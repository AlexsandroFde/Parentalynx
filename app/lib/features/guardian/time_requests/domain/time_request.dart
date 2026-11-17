import '../../../../core/json/json_reader.dart';

/// Pedido de tempo adicional feito pela crianca (protocolo, secao 6).

enum TimeRequestStatus {
  pending('pending', 'Aguardando'),
  approved('approved', 'Aprovado'),
  denied('denied', 'Negado'),
  expired('expired', 'Expirado');

  const TimeRequestStatus(this.code, this.label);

  final String code;
  final String label;

  static TimeRequestStatus parse(String? value) {
    for (final TimeRequestStatus status in values) {
      if (status.code == value) {
        return status;
      }
    }
    return TimeRequestStatus.pending;
  }
}

class TimeRequest {
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

  factory TimeRequest.fromJson(JsonMap json) {
    return TimeRequest(
      id: json.str('id'),
      deviceId: json.strOrNull('deviceId') ?? '',
      childName: json.strOrNull('childName') ?? '',
      createdAt: json.intOr('createdAt', fallback: 0),
      minutes: json.intOrNull('minutes'),
      message: json.strOrNull('message'),
      status: TimeRequestStatus.parse(json.strOrNull('status')),
      grantedMinutes: json.intOrNull('grantedMinutes'),
      resolvedAt: json.intOrNull('resolvedAt'),
    );
  }

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
}
