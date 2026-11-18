import '../../../../core/result/result.dart';
import '../entities/guardian_alert.dart';
import '../repositories/i_alerts_repository.dart';

/// Quantos alertas da conta continuam nao lidos (selo da aba Alertas).
class GetUnreadAlertsCount {
  const GetUnreadAlertsCount(this._alerts);

  final IAlertsRepository _alerts;

  Future<Result<int>> call() async {
    final Result<AlertsPage> result = await _alerts.list(limit: 1);
    return result.map((AlertsPage page) => page.unread);
  }
}
