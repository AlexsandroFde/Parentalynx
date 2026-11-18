import '../../../../core/result/result.dart';
import '../entities/guardian_alert.dart';
import '../repositories/i_alerts_repository.dart';

/// Os alertas mais recentes da conta, para a previa do painel.
class GetRecentAlerts {
  const GetRecentAlerts(this._alerts);

  /// Quantos alertas a previa mostra.
  static const int previewSize = 3;

  final IAlertsRepository _alerts;

  Future<Result<List<GuardianAlert>>> call() async {
    final Result<AlertsPage> result = await _alerts.list(limit: previewSize);
    return result.map((AlertsPage page) => page.alerts);
  }
}
