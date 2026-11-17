import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

/// Motor sobre o WebView do sistema.
class WebViewBrowserEngine implements BrowserEngine {
  WebViewBrowserEngine() : _controller = WebViewController() {
    // Pedidos de camera, microfone e localizacao ficam recusados: o controlador e criado sem
    // tratador de permissoes.
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final BrowserEngineDelegate? delegate = _delegate;
            if (delegate == null) {
              return NavigationDecision.prevent;
            }
            final bool allow = await delegate.onNavigationRequest(
              request.url,
              isMainFrame: request.isMainFrame,
            );
            return allow ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onPageStarted: (String url) => _delegate?.onPageStarted(url),
          onPageFinished: (String url) => _delegate?.onPageFinished(url),
          onProgress: (int progress) => _delegate?.onProgress(progress),
          onUrlChange: (UrlChange change) {
            final String? url = change.url;
            if (url != null) {
              _delegate?.onUrlChanged(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              _delegate?.onMainFrameError(error.description);
            }
          },
          // Certificado invalido: a pagina nao abre.
          onSslAuthError: (SslAuthError request) => unawaited(request.cancel()),
        ),
      ),
    );
  }

  final WebViewController _controller;
  BrowserEngineDelegate? _delegate;

  @override
  void attach(BrowserEngineDelegate delegate) {
    _delegate = delegate;
  }

  @override
  Widget buildView(BuildContext context) => WebViewWidget(controller: _controller);

  @override
  Future<void> load(String url) => _controller.loadRequest(Uri.parse(url));

  @override
  Future<void> reload() => _controller.reload();

  @override
  Future<void> goBack() => _controller.goBack();

  @override
  Future<void> goForward() => _controller.goForward();

  @override
  Future<bool> canGoBack() => _controller.canGoBack();

  @override
  Future<bool> canGoForward() => _controller.canGoForward();

  @override
  Future<String?> title() => _controller.getTitle();
}

final Provider<BrowserEngine> browserEngineProvider = Provider<BrowserEngine>(
  (Ref ref) => WebViewBrowserEngine(),
);
