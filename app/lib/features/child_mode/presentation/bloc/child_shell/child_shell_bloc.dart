import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/navigation/launch_action.dart';
import '../../../../device_linking/domain/entities/link_state.dart';
import '../../../../device_linking/domain/usecases/watch_link_state.dart';
import '../../../domain/usecases/watch_child_launch_action.dart';

part 'child_shell_event.dart';
part 'child_shell_state.dart';

/// Casca do modo crianca: decide o que fazer com a acao pedida por quem abriu o app (tela de
/// bloqueio nativa ou notificacao do controle).
///
/// Enquanto o vinculo e desconhecido ou esta na configuracao inicial, a acao espera. Com o
/// aparelho pronto, a casca leva a pessoa a tela pedida e avisa
/// ([ChildShellLaunchActionHandled]). Sem vinculo, a acao e descartada.
class ChildShellBloc extends Bloc<ChildShellEvent, ChildShellState> {
  ChildShellBloc({required this._launchAction, required this._watchLinkState})
    : super(ChildShellState(phase: _watchLinkState.current.phase)) {
    on<ChildShellStarted>(_onStarted, transformer: restartable());
    on<ChildShellLaunchActionHandled>(_onLaunchActionHandled);
  }

  final WatchChildLaunchAction _launchAction;
  final WatchLinkState _watchLinkState;

  Future<void> _onStarted(ChildShellStarted event, Emitter<ChildShellState> emit) async {
    await Future.wait<void>(<Future<void>>[
      emit.onEach<LaunchAction?>(
        _launchAction(),
        onData: (LaunchAction? action) {
          _apply(emit, ChildShellState(phase: state.phase, pendingAction: action));
        },
      ),
      emit.onEach<LinkState>(
        _watchLinkState(),
        onData: (LinkState link) {
          _apply(emit, ChildShellState(phase: link.phase, pendingAction: state.pendingAction));
        },
      ),
    ]);
  }

  void _onLaunchActionHandled(ChildShellLaunchActionHandled event, Emitter<ChildShellState> emit) {
    if (state.destination != null) {
      _launchAction.consume();
    }
  }

  void _apply(Emitter<ChildShellState> emit, ChildShellState next) {
    emit(next);
    if (next.discardsPendingAction) {
      _launchAction.consume();
    }
  }
}
