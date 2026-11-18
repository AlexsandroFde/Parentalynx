import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../domain/entities/link_state.dart';
import '../../../domain/usecases/resolve_link_state.dart';
import '../../../domain/usecases/watch_link_state.dart';
import '../../texts/child_linking_texts.dart';

part 'child_link_event.dart';
part 'child_link_state.dart';

/// Situacao do vinculo deste aparelho, observada pelo roteador para escolher a tela do modo
/// crianca (entrada, codigo, configuracao inicial ou tela inicial).
///
/// Nao muda a situacao sozinho: os casos de uso (vincular, concluir a configuracao,
/// desvincular, agente desativado) alteram o repositorio, e este BLoC acompanha.
class ChildLinkBloc extends Bloc<ChildLinkEvent, ChildLinkState> {
  ChildLinkBloc({required this._watchLinkState, required this._resolveLinkState})
    : super(ChildLinkState.from(_watchLinkState.current)) {
    on<ChildLinkSubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
    on<ChildLinkLoadRequested>(_onLoadRequested, transformer: droppable());
  }

  final WatchLinkState _watchLinkState;
  final ResolveLinkState _resolveLinkState;

  Future<void> _onSubscriptionRequested(
    ChildLinkSubscriptionRequested event,
    Emitter<ChildLinkState> emit,
  ) {
    return emit.forEach<LinkState>(_watchLinkState(), onData: ChildLinkState.from);
  }

  Future<void> _onLoadRequested(ChildLinkLoadRequested event, Emitter<ChildLinkState> emit) {
    return _resolveLinkState();
  }
}
