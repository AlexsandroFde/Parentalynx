import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/time/formatters.dart';
import '../../../domain/usecases/elevate_session.dart';

part 'elevation_event.dart';
part 'elevation_state.dart';

/// Pedido da senha administrativa para liberar uma operacao (dialogo de elevacao).
class ElevationBloc extends Bloc<ElevationEvent, ElevationState> {
  ElevationBloc({required this._elevateSession}) : super(const ElevationState()) {
    on<ElevationSubmitted>(_onSubmitted, transformer: droppable());
  }

  final ElevateSession _elevateSession;

  Future<void> _onSubmitted(ElevationSubmitted event, Emitter<ElevationState> emit) async {
    if (event.password.isEmpty) {
      emit(const ElevationState(error: 'Digite a senha administrativa.'));
      return;
    }
    emit(const ElevationState(status: FormStatus.submitting));
    final Result<int> result = await _elevateSession(event.password);
    switch (result) {
      case Ok<int>():
        emit(const ElevationState(status: FormStatus.succeeded));
      case Err<int>(:final AppFailure failure):
        emit(ElevationState(error: _messageFor(failure)));
    }
  }

  static String _messageFor(AppFailure failure) {
    if (failure is ApiFailure) {
      if (failure.code == 'invalid_credentials') {
        return 'Senha incorreta.';
      }
      final int? retry = failure.retryAfterSec;
      if (failure.isLocked && retry != null) {
        return 'Muitas tentativas. Tente de novo em ${formatMinutes((retry / 60).ceil())}.';
      }
    }
    return failure.message;
  }
}
