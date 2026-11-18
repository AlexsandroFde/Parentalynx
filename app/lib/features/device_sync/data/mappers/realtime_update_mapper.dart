import '../../../../core/json/json_reader.dart';
import '../../domain/entities/realtime_update.dart';
import '../dto/realtime_message_dto.dart';

/// Converte as mensagens do canal em avisos tipados. Mensagens de tipo desconhecido, sem os
/// campos obrigatorios ou fora do formato sao descartadas: o canal e so um aviso e o estado
/// sempre vem das rotas HTTP.
abstract final class RealtimeUpdateMapper {
  static RealtimeUpdate? fromJson(JsonMap json) {
    final RealtimeMessageDto dto;
    try {
      dto = RealtimeMessageDto.fromJson(json);
    } on JsonFormatException {
      return null;
    }
    return fromDto(dto);
  }

  static RealtimeUpdate? fromDto(RealtimeMessageDto dto) {
    final String? deviceId = dto.deviceId;
    switch (dto.type) {
      case 'device_updated' when deviceId != null:
        return DeviceStateChanged(deviceId);
      case 'link_pending' when deviceId != null:
        return LinkRequested(deviceId);
      case 'link_resolved' when deviceId != null:
        return LinkResolved(deviceId: deviceId, status: dto.status ?? '');
      case 'policy_applied' when deviceId != null:
        return PolicyApplied(deviceId: deviceId, version: dto.version ?? 0);
      case 'time_request' when deviceId != null:
        return TimeRequestReceived(deviceId: deviceId, requestId: dto.requestId ?? '');
      case 'alert':
        final RealtimeAlertDto? alert = dto.alert;
        return alert == null ? null : AlertRaised(alertFrom(alert));
      default:
        return null;
    }
  }

  static RealtimeAlert alertFrom(RealtimeAlertDto dto) {
    return RealtimeAlert(
      id: dto.id,
      type: dto.type ?? '',
      deviceId: dto.deviceId,
      childName: dto.childName,
      createdAt: dto.createdAt ?? 0,
      readAt: dto.readAt,
      notify: dto.notify ?? true,
      title: dto.title ?? '',
      body: dto.body ?? '',
    );
  }
}
