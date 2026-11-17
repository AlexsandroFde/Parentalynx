import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_providers.dart';
import '../../agent/data/native_guard.dart';
import '../domain/browser_navigation.dart';

/// Acesso ao filtro e ao historico do navegador gerenciado, que ficam no agente nativo.
class BrowserRepository {
  const BrowserRepository(this._api);

  final BrowserApi _api;

  Future<BrowserSettings> settings() async {
    final BrowserConfig config = await guardNative(_api.getConfig);
    return BrowserSettings(
      enabled: config.enabled,
      logHistory: config.logHistory,
      safeSearch: config.safeSearch,
      allowlistMode: config.allowlistMode,
    );
  }

  /// Decide se a navegacao de pagina principal pode prosseguir.
  Future<NavigationVerdict> evaluate(String url) async {
    final UrlDecision decision = await guardNative(() => _api.evaluateUrl(url));
    return NavigationVerdict(
      allowed: decision.allowed,
      reason: decision.reason,
      category: decision.category,
      rewrittenUrl: decision.rewrittenUrl,
    );
  }

  /// Registra uma pagina aberta ou bloqueada no historico enviado ao responsavel.
  Future<void> recordVisit(String url, {String? title, bool blocked = false, String? reason}) {
    return guardNative(() => _api.recordVisit(url, title, blocked, reason));
  }
}

final Provider<BrowserRepository> browserRepositoryProvider = Provider<BrowserRepository>(
  (Ref ref) => BrowserRepository(ref.watch(browserApiProvider)),
);
