import '../../../../core/result/result.dart';

/// Abre o navegador gerenciado, que roda como um app separado no aparelho.
abstract interface class IManagedBrowserLauncher {
  /// Abre o navegador, opcionalmente ja no endereco [url].
  Future<Result<void>> open({String? url});
}
