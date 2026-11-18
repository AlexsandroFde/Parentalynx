import 'dart:async';

import '../../../../core/result/result.dart';
import '../entities/guardian_alert.dart';
import '../repositories/i_alerts_repository.dart';
import '../services/i_alert_polling_service.dart';

/// Primeira pagina da central de alertas.
///
/// Ao carregar, avisa o lado nativo de que os alertas ate o mais novo ja foram vistos, para
/// a busca em segundo plano nao notificar de novo o que a pessoa acabou de ver.
class LoadLatestAlerts {
  const LoadLatestAlerts({required this._alerts, required this._polling});

  /// Alertas por pagina na central.
  static const int pageSize = 30;

  final IAlertsRepository _alerts;
  final IAlertPollingService _polling;

  Future<Result<AlertsPage>> call() async {
    final Result<AlertsPage> result = await _alerts.list(limit: pageSize);
    if (result case Ok<AlertsPage>(:final AlertsPage value) when value.latestId > 0) {
      unawaited(_polling.markSeen(value.latestId));
    }
    return result;
  }
}
