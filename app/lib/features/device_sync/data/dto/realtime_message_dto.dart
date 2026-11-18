import '../../../../core/json/json_reader.dart';

/// Mensagem do canal em tempo real no formato do protocolo (secao 7): um `type` e os campos
/// daquele tipo. Campos ausentes ficam nulos.
final class RealtimeMessageDto {
  const RealtimeMessageDto({
    required this.type,
    this.deviceId,
    this.status,
    this.version,
    this.requestId,
    this.alert,
  });

  factory RealtimeMessageDto.fromJson(JsonMap json) {
    final JsonMap? alert = json.objOrNull('alert');
    return RealtimeMessageDto(
      type: json.strOrNull('type') ?? '',
      deviceId: json.strOrNull('deviceId'),
      status: json.strOrNull('status'),
      version: json.intOrNull('version'),
      requestId: json.strOrNull('requestId'),
      alert: alert == null ? null : RealtimeAlertDto.fromJson(alert),
    );
  }

  final String type;
  final String? deviceId;
  final String? status;
  final int? version;
  final String? requestId;
  final RealtimeAlertDto? alert;
}

/// Alerta embutido na mensagem `alert`.
final class RealtimeAlertDto {
  const RealtimeAlertDto({
    required this.id,
    this.type,
    this.deviceId,
    this.childName,
    this.createdAt,
    this.readAt,
    this.notify,
    this.title,
    this.body,
  });

  factory RealtimeAlertDto.fromJson(JsonMap json) {
    return RealtimeAlertDto(
      id: json.integer('id'),
      type: json.strOrNull('type'),
      deviceId: json.strOrNull('deviceId'),
      childName: json.strOrNull('childName'),
      createdAt: json.intOrNull('createdAt'),
      readAt: json.intOrNull('readAt'),
      notify: json.has('notify') ? json.boolean('notify') : null,
      title: json.strOrNull('title'),
      body: json.strOrNull('body'),
    );
  }

  final int id;
  final String? type;
  final String? deviceId;
  final String? childName;
  final int? createdAt;
  final int? readAt;
  final bool? notify;
  final String? title;
  final String? body;
}
