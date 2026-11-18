import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Avisa o roteador para reavaliar os redirecionamentos quando algum dos fluxos muda (perfil,
/// sessao do responsavel, vinculo da crianca).
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(List<Stream<Object?>> streams) {
    for (final Stream<Object?> stream in streams) {
      _subscriptions.add(stream.listen((Object? _) => notifyListeners()));
    }
  }

  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];

  @override
  void dispose() {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

/// Local onde a pessoa estava quando o painel bloqueou, para voltar depois de desbloquear.
class ReturnLocation {
  String? _location;

  void remember(String location) {
    _location = location;
  }

  /// Devolve o local guardado e o esquece.
  String? take() {
    final String? location = _location;
    _location = null;
    return location;
  }
}
