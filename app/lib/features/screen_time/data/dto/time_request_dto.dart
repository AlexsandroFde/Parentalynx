import '../../../../core/json/json_reader.dart';

/// Pedido de tempo no formato do protocolo (secao 4). Campos ausentes ficam nulos.
final class TimeRequestDto {
  const TimeRequestDto({
    required this.id,
    this.deviceId,
    this.childName,
    this.createdAt,
    this.minutes,
    this.message,
    this.status,
    this.grantedMinutes,
    this.resolvedAt,
  });

  factory TimeRequestDto.fromJson(JsonMap json) {
    return TimeRequestDto(
      id: json.str('id'),
      deviceId: json.strOrNull('deviceId'),
      childName: json.strOrNull('childName'),
      createdAt: json.intOrNull('createdAt'),
      minutes: json.intOrNull('minutes'),
      message: json.strOrNull('message'),
      status: json.strOrNull('status'),
      grantedMinutes: json.intOrNull('grantedMinutes'),
      resolvedAt: json.intOrNull('resolvedAt'),
    );
  }

  final String id;
  final String? deviceId;
  final String? childName;
  final int? createdAt;
  final int? minutes;
  final String? message;

  /// `pending`, `approved`, `denied` ou `expired`.
  final String? status;
  final int? grantedMinutes;
  final int? resolvedAt;
}
