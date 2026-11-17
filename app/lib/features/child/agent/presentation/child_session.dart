import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../shared/no_retry.dart';
import '../data/child_agent_repository.dart';
import '../domain/child_models.dart';

/// Situacao do vinculo deste aparelho, usada pelo roteador do modo crianca.
enum ChildLinkPhase {
  /// Ainda consultando o agente nativo.
  unknown,

  /// A consulta ao agente falhou. A tela de entrada oferece tentar de novo.
  failed,

  /// Sem vinculo: mostra a tela do codigo.
  unlinked,

  /// Acabou de vincular: passa pela transparencia e pelas permissoes.
  onboarding,

  /// Vinculado e configurado: tela inicial.
  ready,
}

final NotifierProvider<ChildLinkController, ChildLinkPhase> childLinkProvider =
    NotifierProvider<ChildLinkController, ChildLinkPhase>(ChildLinkController.new);

class ChildLinkController extends Notifier<ChildLinkPhase> {
  bool _loading = false;

  // Nao consulta o agente aqui: o roteador observa este provedor nos dois modos do app, e so
  // a tela de entrada do modo crianca deve disparar a consulta.
  @override
  ChildLinkPhase build() => ChildLinkPhase.unknown;

  /// Pergunta ao agente nativo se o aparelho esta vinculado. Chamado pela tela de entrada do
  /// modo crianca.
  Future<void> load() async {
    if (_loading) {
      return;
    }
    if (state == ChildLinkPhase.failed) {
      state = ChildLinkPhase.unknown;
    }
    if (state != ChildLinkPhase.unknown) {
      return;
    }
    _loading = true;
    try {
      final ChildStatus status = await ref.read(childAgentRepositoryProvider).status();
      if (!ref.mounted) {
        return;
      }
      // Um vinculo concluido enquanto a consulta estava em andamento tem prioridade.
      if (state == ChildLinkPhase.unknown) {
        state = status.active ? ChildLinkPhase.ready : ChildLinkPhase.unlinked;
      }
    } on AppFailure {
      if (ref.mounted && state == ChildLinkPhase.unknown) {
        state = ChildLinkPhase.failed;
      }
    } finally {
      _loading = false;
    }
  }

  /// O vinculo acabou de ser aprovado e o agente foi ligado.
  void markLinked() {
    ref.read(childLinkNoticeProvider.notifier).clear();
    state = ChildLinkPhase.onboarding;
  }

  /// A configuracao inicial (transparencia e permissoes) terminou.
  void finishOnboarding() {
    if (state == ChildLinkPhase.onboarding) {
      state = ChildLinkPhase.ready;
    }
  }

  /// O aparelho deixou de estar vinculado. [notice] explica o motivo na tela do codigo.
  void markUnlinked({String? notice}) {
    if (notice != null) {
      ref.read(childLinkNoticeProvider.notifier).show(notice);
    }
    state = ChildLinkPhase.unlinked;
  }

  /// O agente respondeu que nao esta mais ativo (o responsavel removeu o vinculo).
  void onAgentInactive() {
    if (state == ChildLinkPhase.ready || state == ChildLinkPhase.onboarding) {
      markUnlinked(
        notice:
            'O vínculo deste aparelho foi removido pelo responsável. '
            'Para voltar a usar o controle, peça um novo código.',
      );
    }
  }
}

/// Aviso mostrado na tela do codigo depois que um vinculo foi desfeito.
final NotifierProvider<ChildLinkNoticeController, String?> childLinkNoticeProvider =
    NotifierProvider<ChildLinkNoticeController, String?>(ChildLinkNoticeController.new);

class ChildLinkNoticeController extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) {
    state = message;
  }

  void clear() {
    state = null;
  }
}

/// Verdadeiro enquanto o app esta em primeiro plano. Com o app em segundo plano as consultas
/// periodicas ao agente param, para nao gastar bateria.
final NotifierProvider<ChildForegroundController, bool> childForegroundProvider =
    NotifierProvider<ChildForegroundController, bool>(ChildForegroundController.new);

class ChildForegroundController extends Notifier<bool> {
  @override
  bool build() => true;

  void set({required bool foreground}) {
    state = foreground;
  }
}

/// Intervalo de consulta do estado do agente enquanto a tela esta visivel.
const Duration agentPollInterval = Duration(seconds: 1);

/// Retrato do agente, atualizado a cada segundo enquanto alguma tela o observa.
///
/// O tempo restante vem pronto do lado nativo a cada consulta, entao a contagem regressiva da
/// tela acompanha a contagem real, sem relogio paralelo no Dart.
final agentStatusProvider = AsyncNotifierProvider.autoDispose<AgentStatusController, ChildStatus>(
  AgentStatusController.new,
  retry: noRetry,
);

class AgentStatusController extends AsyncNotifier<ChildStatus> {
  Timer? _timer;
  bool _busy = false;

  @override
  Future<ChildStatus> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(agentPollInterval, (Timer timer) => unawaited(_tick()));
    ref.onDispose(() => _timer?.cancel());
    final ChildStatus status = await ref.read(childAgentRepositoryProvider).status();
    _reportIfInactive(status);
    return status;
  }

  /// Consulta agora, sem esperar o proximo ciclo (depois de uma acao que muda o estado).
  Future<void> refresh() => _tick(force: true);

  Future<void> _tick({bool force = false}) async {
    if (_busy || (!force && !ref.read(childForegroundProvider))) {
      return;
    }
    _busy = true;
    try {
      final ChildStatus status = await ref.read(childAgentRepositoryProvider).status();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<ChildStatus>(status);
      _reportIfInactive(status);
    } on AppFailure catch (error, stack) {
      // Falha passageira: mantem o ultimo retrato na tela. So mostra erro se nao ha nenhum.
      if (ref.mounted && !state.hasValue) {
        state = AsyncError<ChildStatus>(error, stack);
      }
    } finally {
      _busy = false;
    }
  }

  void _reportIfInactive(ChildStatus status) {
    if (!status.active && ref.mounted) {
      ref.read(childLinkProvider.notifier).onAgentInactive();
    }
  }
}
