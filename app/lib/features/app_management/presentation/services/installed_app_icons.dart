import 'dart:typed_data';

import '../../domain/usecases/get_installed_app_icon.dart';

/// Icones dos apps deste aparelho para as telas do modo crianca.
///
/// Servico de interface entregue pela arvore de widgets (`RepositoryProvider`). Cada icone e
/// buscado no agente nativo uma vez por sessao.
abstract interface class InstalledAppIcons {
  /// Icone ja carregado, para desenhar sem esperar. Nulo quando ainda nao veio ou nao ha.
  Uint8List? cached(String packageName);

  /// Icone em PNG, ou nulo quando nao ha (ou quando o agente nao respondeu).
  Future<Uint8List?> iconFor(String packageName);
}

/// Busca os icones pelo caso de uso [GetInstalledAppIcon] e guarda em memoria.
class SessionInstalledAppIcons implements InstalledAppIcons {
  SessionInstalledAppIcons(this._getIcon);

  final GetInstalledAppIcon _getIcon;
  final Map<String, Future<Uint8List?>> _requests = <String, Future<Uint8List?>>{};
  final Map<String, Uint8List?> _loaded = <String, Uint8List?>{};

  @override
  Uint8List? cached(String packageName) => _loaded[packageName];

  @override
  Future<Uint8List?> iconFor(String packageName) {
    return _requests.putIfAbsent(packageName, () async {
      final Uint8List? bytes = (await _getIcon(packageName)).valueOrNull;
      _loaded[packageName] = bytes;
      return bytes;
    });
  }
}
