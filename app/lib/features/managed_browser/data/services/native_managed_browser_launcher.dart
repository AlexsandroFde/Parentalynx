import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/i_managed_browser_launcher.dart';

/// Abre a atividade nativa do navegador gerenciado ([ChildAgentApi.openManagedBrowser]).
class NativeManagedBrowserLauncher implements IManagedBrowserLauncher {
  const NativeManagedBrowserLauncher(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<void>> open({String? url}) {
    return callNative<void>(
      () => _api.openManagedBrowser(url),
      fallback: 'Não foi possível abrir o navegador.',
    );
  }
}
