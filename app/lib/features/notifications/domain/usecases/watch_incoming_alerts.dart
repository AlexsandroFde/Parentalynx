import '../../../device_sync/domain/entities/realtime_update.dart';
import '../../../device_sync/domain/usecases/watch_realtime_updates.dart';
import '../entities/guardian_alert.dart';

/// Alertas que chegam pelo canal em tempo real enquanto o painel esta aberto.
class WatchIncomingAlerts {
  const WatchIncomingAlerts(this._realtime);

  final WatchRealtimeUpdates _realtime;

  Stream<GuardianAlert> call() {
    return _realtime().where((RealtimeUpdate update) => update is AlertRaised).map((
      RealtimeUpdate update,
    ) {
      final RealtimeAlert alert = (update as AlertRaised).alert;
      return GuardianAlert(
        id: alert.id,
        type: alert.type,
        deviceId: alert.deviceId,
        childName: alert.childName,
        createdAt: alert.createdAt,
        readAt: alert.readAt,
        notify: alert.notify,
        title: alert.title,
        body: alert.body,
      );
    });
  }
}
