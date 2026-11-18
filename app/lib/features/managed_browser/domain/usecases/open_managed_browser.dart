import '../../../../core/result/result.dart';
import '../services/i_managed_browser_launcher.dart';

/// Abre o navegador gerenciado, opcionalmente ja em um endereco.
class OpenManagedBrowser {
  const OpenManagedBrowser(this._launcher);

  final IManagedBrowserLauncher _launcher;

  Future<Result<void>> call({String? url}) => _launcher.open(url: url);
}
