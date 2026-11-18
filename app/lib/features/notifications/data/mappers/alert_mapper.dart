import '../../domain/entities/guardian_alert.dart';
import '../dto/alert_dto.dart';

/// Converte os alertas do protocolo nas entidades, aplicando os valores padrao.
abstract final class AlertMapper {
  static GuardianAlert alert(AlertDto dto) {
    return GuardianAlert(
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

  static AlertsPage page(AlertsPageDto dto) {
    return AlertsPage(
      alerts: dto.alerts.map(alert).toList(),
      latestId: dto.latestId ?? 0,
      unread: dto.unread ?? 0,
    );
  }
}
