import '../../../../core/result/result.dart';
import '../repositories/i_alerts_repository.dart';

/// Marca todos os alertas da conta como lidos. Devolve quantos continuam nao lidos.
class MarkAllAlertsRead {
  const MarkAllAlertsRead(this._alerts);

  final IAlertsRepository _alerts;

  Future<Result<int>> call() => _alerts.markRead(all: true);
}
