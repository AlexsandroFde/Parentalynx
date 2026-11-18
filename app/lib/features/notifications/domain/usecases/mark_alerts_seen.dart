import '../services/i_alert_polling_service.dart';

/// Avisa o lado nativo de que os alertas ate [alertId] ja foram vistos com o app aberto, para
/// a busca em segundo plano nao notificar de novo.
class MarkAlertsSeen {
  const MarkAlertsSeen(this._polling);

  final IAlertPollingService _polling;

  Future<void> call(int alertId) async {
    if (alertId > 0) {
      await _polling.markSeen(alertId);
    }
  }
}
