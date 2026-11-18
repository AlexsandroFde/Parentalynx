import 'dart:async';

import 'native_api.g.dart';

/// Recebe os avisos do lado nativo ([NativeEventsApi]) e os distribui em fluxos.
///
/// A ponte aceita um unico receptor por motor Flutter. Este despachante e esse receptor, e
/// cada funcionalidade assina so o fluxo que lhe interessa.
class NativeEventsDispatcher implements NativeEventsApi {
  NativeEventsDispatcher();

  final StreamController<String> _launchActions = StreamController<String>.broadcast();
  final StreamController<String> _openUrls = StreamController<String>.broadcast();

  /// Passa a receber os avisos do lado nativo.
  void attach() => NativeEventsApi.setUp(this);

  /// Deixa de receber os avisos.
  void detach() => NativeEventsApi.setUp(null);

  /// Acoes com que a atividade ja aberta foi reaberta (`alerts`, `guardian_area`, ...).
  Stream<String> get launchActions => _launchActions.stream;

  /// Enderecos recebidos pelo navegador gerenciado ja aberto.
  Stream<String> get openUrls => _openUrls.stream;

  @override
  void onLaunchAction(String action) => _launchActions.add(action);

  @override
  void onOpenUrl(String url) => _openUrls.add(url);

  Future<void> dispose() async {
    await _launchActions.close();
    await _openUrls.close();
  }
}
