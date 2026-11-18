import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/navigation/launch_action.dart';
import '../../../domain/usecases/watch_launch_action.dart';

part 'guardian_shell_event.dart';
part 'guardian_shell_state.dart';

/// Casca do painel: leva a pessoa para a aba certa quando o app e aberto por uma
/// notificacao de alerta.
///
/// So trata a acao `alerts`. As acoes do modo crianca ficam pendentes para quem as entende.
class GuardianShellBloc extends Bloc<GuardianShellEvent, GuardianShellState> {
  GuardianShellBloc({required this._launchAction}) : super(const GuardianShellState()) {
    on<GuardianShellStarted>(_onStarted, transformer: restartable());
    on<GuardianShellLaunchActionHandled>(_onHandled);
  }

  final WatchLaunchAction _launchAction;

  Future<void> _onStarted(GuardianShellStarted event, Emitter<GuardianShellState> emit) {
    return emit.forEach<LaunchAction?>(
      _launchAction(),
      onData: (LaunchAction? action) => GuardianShellState(pendingAction: action),
    );
  }

  void _onHandled(GuardianShellLaunchActionHandled event, Emitter<GuardianShellState> emit) {
    if (state.opensAlerts) {
      _launchAction.consume();
    }
  }
}
