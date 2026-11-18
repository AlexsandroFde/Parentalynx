import 'package:flutter/widgets.dart';

/// Quem recebe os eventos do motor de paginas.
abstract interface class BrowserEngineDelegate {
  /// Decide se uma navegacao pode prosseguir. Devolve falso para impedir.
  Future<bool> onNavigationRequest(String url, {required bool isMainFrame});

  void onPageStarted(String url);

  void onPageFinished(String url);

  void onProgress(int progress);

  void onUrlChanged(String url);

  void onMainFrameError(String description);
}

/// Motor que carrega e mostra as paginas. Existe como interface para que os testes troquem o
/// WebView real, que so funciona em um aparelho.
///
/// E um componente de interface: a tela mostra [buildView] e o `BrowserBloc` comanda a
/// navegacao e recebe os eventos pelo [BrowserEngineDelegate].
abstract interface class BrowserEngine {
  void attach(BrowserEngineDelegate delegate);

  Widget buildView(BuildContext context);

  Future<void> load(String url);

  Future<void> reload();

  Future<void> goBack();

  Future<void> goForward();

  Future<bool> canGoBack();

  Future<bool> canGoForward();

  Future<String?> title();
}
