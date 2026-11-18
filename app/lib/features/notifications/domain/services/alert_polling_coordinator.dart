import 'dart:async';

import '../../../authentication/domain/entities/guardian_session.dart';
import '../../../authentication/domain/usecases/watch_guardian_session.dart';
import 'i_alert_polling_service.dart';

/// Mantem a busca de alertas em segundo plano em acordo com a sessao do responsavel.
///
/// Observa a sessao (padrao Observer) em vez de ser chamado por quem abre ou encerra a
/// sessao: a autenticacao nao precisa saber que existem alertas.
/// - A sessao abriu (entrada, criacao de conta, recuperacao ou desbloqueio): liga a busca.
/// - A sessao terminou (saida, sessao recusada, conta excluida): desliga a busca.
/// - Bloquear o painel nao muda nada: os alertas continuam chegando com o painel bloqueado.
///
/// O estado inicial nao muda nada no lado nativo, que guarda a escolha entre aberturas.
class AlertPollingCoordinator {
  AlertPollingCoordinator({required this._session, required this._polling});

  final WatchGuardianSession _session;
  final IAlertPollingService _polling;

  StreamSubscription<GuardianSessionState>? _subscription;
  GuardianSessionState? _previous;

  bool get isRunning => _subscription != null;

  /// Passa a acompanhar a sessao. Chamado uma vez na inicializacao do app.
  void start() {
    _subscription ??= _session().listen(_onSessionChanged);
  }

  void _onSessionChanged(GuardianSessionState state) {
    final GuardianSessionState? previous = _previous;
    _previous = state;
    if (previous == null) {
      return;
    }
    if (state is SessionOpen && previous is! SessionOpen) {
      unawaited(_polling.enable());
    } else if (state is SessionSignedOut && previous is! SessionSignedOut) {
      unawaited(_polling.disable());
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _previous = null;
  }
}
