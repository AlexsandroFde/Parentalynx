import '../services/i_browser_url_requests.dart';

/// Enderecos que outros apps pedem para o navegador abrir, a partir de agora.
class WatchBrowserUrlRequests {
  const WatchBrowserUrlRequests(this._requests);

  final IBrowserUrlRequests _requests;

  Stream<String> call() => _requests.watch();
}
