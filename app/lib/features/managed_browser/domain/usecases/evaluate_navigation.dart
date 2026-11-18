import '../../../../core/result/result.dart';
import '../entities/navigation_verdict.dart';
import '../services/i_web_filter_service.dart';

/// Pergunta ao filtro se uma pagina principal pode abrir.
///
/// Sem resposta do filtro a pagina nao abre: a falha vira [NavigationVerdict.checkFailed].
class EvaluateNavigation {
  const EvaluateNavigation(this._filter);

  final IWebFilterService _filter;

  Future<NavigationVerdict> call(String url) async {
    final Result<NavigationVerdict> result = await _filter.evaluate(url);
    return result.valueOrNull ?? const NavigationVerdict.checkFailed();
  }
}
