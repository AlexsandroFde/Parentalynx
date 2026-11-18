import '../../../../core/result/result.dart';
import '../repositories/i_alerts_repository.dart';

/// Marca um alerta como lido. Devolve quantos continuam nao lidos.
class MarkAlertRead {
  const MarkAlertRead(this._alerts);

  final IAlertsRepository _alerts;

  Future<Result<int>> call(int alertId) => _alerts.markRead(ids: <int>[alertId]);
}
