import 'dart:async';

import 'package:flutter/services.dart';

import '../navigation/launch_action.dart';
import '../utils/observable_value.dart';
import 'native_api.g.dart';
import 'native_events.dart';

/// Acoes de abertura vindas do lado nativo: a que abriu a atividade (consultada uma vez) e
/// as que chegam com a atividade ja aberta.
class NativeLaunchActionSource implements LaunchActionSource {
  NativeLaunchActionSource({required this._api, required this._events});

  final AppModeApi _api;
  final NativeEventsDispatcher _events;
  final ObservableValue<LaunchAction?> _pending = ObservableValue<LaunchAction?>.seeded(null);
  StreamSubscription<String>? _subscription;
  bool _started = false;

  /// Consulta a acao de abertura e passa a ouvir as proximas. Chamado uma vez no inicio.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _subscription = _events.launchActions.listen(_receive);
    try {
      final String? initial = await _api.consumeLaunchAction();
      if (initial != null) {
        _receive(initial);
      }
    } on PlatformException {
      // Sem acao de abertura. Nada a fazer.
    }
  }

  void _receive(String code) {
    final LaunchAction? action = LaunchAction.parse(code);
    if (action != null) {
      _pending.add(action);
    }
  }

  @override
  Stream<LaunchAction?> watchPending() => _pending.stream;

  @override
  void consume() => _pending.add(null);

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _pending.close();
  }
}
