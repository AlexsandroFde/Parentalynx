import '../entities/browser_settings.dart';
import '../entities/browser_visit.dart';
import '../entities/navigation_verdict.dart';
import '../services/i_web_filter_service.dart';

/// Registra uma pagina aberta ou barrada no historico que o responsavel ve.
///
/// So registra quando a politica pede o historico ([BrowserSettings.logHistory]). Bloqueios
/// por falta de resposta do filtro nao entram: nao sao uma tentativa de abrir um site
/// proibido. O historico e melhor esforco: uma falha ao registrar nao interrompe a
/// navegacao.
class RecordBrowserVisit {
  const RecordBrowserVisit(this._filter);

  final IWebFilterService _filter;

  Future<void> call(BrowserVisit visit, {required BrowserSettings? settings}) async {
    if (settings == null || !settings.logHistory) {
      return;
    }
    if (visit.blocked && visit.reason == NavigationVerdict.checkFailedReason) {
      return;
    }
    await _filter.recordVisit(visit);
  }
}
