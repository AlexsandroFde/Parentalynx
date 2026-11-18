import '../../../../core/result/result.dart';
import '../entities/browser_settings.dart';
import '../services/i_web_filter_service.dart';

/// Le a configuracao do navegador. Chamado ao abrir e quando o navegador volta ao primeiro
/// plano, porque as regras podem ter mudado.
class GetBrowserSettings {
  const GetBrowserSettings(this._filter);

  final IWebFilterService _filter;

  Future<Result<BrowserSettings>> call() => _filter.settings();
}
