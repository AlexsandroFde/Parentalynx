import 'package:flutter/widgets.dart';
import 'package:parentalynx/features/managed_browser/presentation/engine/browser_engine.dart';

/// Motor de paginas falso: registra o que foi pedido e mostra um quadro no lugar do WebView.
///
/// [delegate] e quem o BLoC registrou; os testes chamam os metodos dele para simular os
/// eventos do WebView (link tocado, pagina carregada...).
class FakeBrowserEngine implements BrowserEngine {
  final List<String> loaded = <String>[];
  BrowserEngineDelegate? delegate;
  bool back = false;
  bool forward = false;
  String? pageTitle;
  int reloads = 0;
  int backs = 0;
  int forwards = 0;

  @override
  void attach(BrowserEngineDelegate delegate) {
    this.delegate = delegate;
  }

  @override
  Widget buildView(BuildContext context) => const SizedBox.expand();

  @override
  Future<void> load(String url) async {
    loaded.add(url);
  }

  @override
  Future<void> reload() async {
    reloads += 1;
  }

  @override
  Future<void> goBack() async {
    backs += 1;
  }

  @override
  Future<void> goForward() async {
    forwards += 1;
  }

  @override
  Future<bool> canGoBack() async => back;

  @override
  Future<bool> canGoForward() async => forward;

  @override
  Future<String?> title() async => pageTitle;
}
