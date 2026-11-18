import '../../../../core/result/result.dart';
import '../entities/guardian_alert.dart';
import '../repositories/i_alerts_repository.dart';
import 'load_latest_alerts.dart';

/// Pagina seguinte de alertas mais antigos que [beforeId].
class LoadOlderAlerts {
  const LoadOlderAlerts(this._alerts);

  final IAlertsRepository _alerts;

  Future<Result<AlertsPage>> call(int beforeId) {
    return _alerts.list(before: beforeId, limit: LoadLatestAlerts.pageSize);
  }
}
