import '../../../../core/platform/native_api.g.dart';
import '../../domain/entities/browser_settings.dart';
import '../../domain/entities/navigation_verdict.dart';

/// Converte as respostas do filtro nativo nas entidades do navegador.
abstract final class BrowserMapper {
  static BrowserSettings settings(BrowserConfig config) {
    return BrowserSettings(
      enabled: config.enabled,
      logHistory: config.logHistory,
      safeSearch: config.safeSearch,
      allowlistMode: config.allowlistMode,
    );
  }

  static NavigationVerdict verdict(UrlDecision decision) {
    return NavigationVerdict(
      allowed: decision.allowed,
      reason: decision.reason,
      category: decision.category,
      rewrittenUrl: decision.rewrittenUrl,
    );
  }
}
