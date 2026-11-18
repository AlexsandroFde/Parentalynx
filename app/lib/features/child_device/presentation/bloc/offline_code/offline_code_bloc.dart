import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/time/clock.dart';
import '../../../domain/entities/offline_access_code.dart';
import '../../../domain/usecases/compute_offline_access_code.dart';

part 'offline_code_event.dart';
part 'offline_code_state.dart';

/// Codigo de acesso offline do momento, recalculado a cada segundo enquanto a folha estiver
/// aberta, com a contagem ate ele mudar.
class OfflineCodeBloc extends Bloc<OfflineCodeEvent, OfflineCodeState> {
  OfflineCodeBloc({
    required this._secret,
    required this._compute,
    required this._clock,
    this.tick = const Duration(seconds: 1),
  }) : super(OfflineCodeState(_compute(_secret, _clock.nowMs()))) {
    on<OfflineCodeStarted>(_onStarted, transformer: restartable());
  }

  final String _secret;
  final ComputeOfflineAccessCode _compute;
  final Clock _clock;

  /// Intervalo de atualizacao.
  final Duration tick;

  Future<void> _onStarted(OfflineCodeStarted event, Emitter<OfflineCodeState> emit) {
    return emit.forEach<void>(
      Stream<void>.periodic(tick),
      onData: (_) => OfflineCodeState(_compute(_secret, _clock.nowMs())),
    );
  }
}
