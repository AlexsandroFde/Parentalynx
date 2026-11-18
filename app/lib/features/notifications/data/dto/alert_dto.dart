import '../../../../core/json/json_reader.dart';

/// Alerta no formato do protocolo (secao 2.5). Campos opcionais ficam nulos.
final class AlertDto {
  const AlertDto({
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

  factory AlertDto.fromJson(JsonMap json) {
    return AlertDto(
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

/// Resposta de `GET /v1/guardian/alerts`.
final class AlertsPageDto {
  const AlertsPageDto({this.alerts = const <AlertDto>[], this.latestId, this.unread});

  factory AlertsPageDto.fromJson(JsonMap json) {
    return AlertsPageDto(
      alerts: json.objList('alerts').map(AlertDto.fromJson).toList(),
      latestId: json.intOrNull('latestId'),
      unread: json.intOrNull('unread'),
    );
  }

  final List<AlertDto> alerts;
  final int? latestId;
  final int? unread;
}

/// Le o mapa de preferencias de notificacao, ignorando valores que nao sao booleanos.
Map<String, bool> readNotificationPrefs(JsonMap json) {
  return <String, bool>{
    for (final String key in json.keys)
      if (json.raw[key] is bool) key: json.boolean(key),
  };
}
