import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/browser_settings.dart';
import '../../domain/entities/browser_visit.dart';
import '../../domain/entities/navigation_verdict.dart';
import '../../domain/services/i_web_filter_service.dart';
import '../mappers/browser_mapper.dart';

/// Filtro e historico do navegador pela ponte com o agente nativo ([BrowserApi]).
class NativeWebFilterService implements IWebFilterService {
  const NativeWebFilterService(this._api);

  final BrowserApi _api;

  @override
  Future<Result<BrowserSettings>> settings() async {
    final Result<BrowserConfig> config = await callNative<BrowserConfig>(_api.getConfig);
    return config.map(BrowserMapper.settings);
  }

  @override
  Future<Result<NavigationVerdict>> evaluate(String url) async {
    final Result<UrlDecision> decision = await callNative<UrlDecision>(() => _api.evaluateUrl(url));
    return decision.map(BrowserMapper.verdict);
  }

  @override
  Future<Result<void>> recordVisit(BrowserVisit visit) {
    return callNative<void>(
      () => _api.recordVisit(visit.url, visit.title, visit.blocked, visit.reason),
    );
  }
}
