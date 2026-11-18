import 'dart:async';

import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/platform/native_events.dart';
import '../../domain/services/i_browser_url_requests.dart';

/// Enderecos pedidos ao navegador pelo lado nativo: o da abertura ([BrowserApi]) e os que
/// chegam com o navegador ja aberto ([NativeEventsDispatcher.openUrls]).
class NativeBrowserUrlRequests implements IBrowserUrlRequests {
  const NativeBrowserUrlRequests({required this._api, required this._events});

  final BrowserApi _api;
  final NativeEventsDispatcher _events;

  @override
  Stream<String> watch() {
    return Stream<String>.multi((MultiStreamController<String> controller) {
      // Assina os avisos antes de consultar o endereco de abertura, para nenhum endereco
      // recebido nesse meio tempo se perder.
      final StreamSubscription<String> incoming = _events.openUrls.listen(controller.add);
      controller.onCancel = incoming.cancel;
      unawaited(
        callNativeOr<String?>(_api.consumeInitialUrl, null).then((String? url) {
          if (url != null && controller.hasListener) {
            controller.add(url);
          }
        }),
      );
    });
  }
}
