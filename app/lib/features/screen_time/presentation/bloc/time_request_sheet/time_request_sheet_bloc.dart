import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/usecases/submit_time_request.dart';

part 'time_request_sheet_event.dart';
part 'time_request_sheet_state.dart';

/// Pedido de mais tempo feito pela crianca (folha "Pedir mais tempo").
class TimeRequestSheetBloc extends Bloc<TimeRequestSheetEvent, TimeRequestSheetState> {
  TimeRequestSheetBloc({required this._submitTimeRequest}) : super(const TimeRequestSheetState()) {
    on<TimeRequestSheetOpened>(_onOpened);
    on<TimeRequestMinutesSelected>(_onMinutesSelected);
    on<TimeRequestSheetSubmitted>(_onSubmitted, transformer: droppable());
  }

  /// Opcoes de tempo que a crianca pode pedir, em minutos.
  static const List<int> minuteOptions = <int>[15, 30, 60];

  /// Tempo ja escolhido quando a folha abre.
  static const int defaultMinutes = 30;

  final SubmitTimeRequest _submitTimeRequest;

  void _onOpened(TimeRequestSheetOpened event, Emitter<TimeRequestSheetState> emit) {
    emit(const TimeRequestSheetState());
  }

  void _onMinutesSelected(TimeRequestMinutesSelected event, Emitter<TimeRequestSheetState> emit) {
    if (!state.status.isSubmitting) {
      emit(state.copyWith(minutes: event.minutes, error: state.error));
    }
  }

  Future<void> _onSubmitted(
    TimeRequestSheetSubmitted event,
    Emitter<TimeRequestSheetState> emit,
  ) async {
    emit(state.copyWith(status: FormStatus.submitting));
    final Result<String> result = await _submitTimeRequest(
      minutes: state.minutes,
      message: event.message,
    );
    switch (result) {
      case Ok<String>():
        emit(state.copyWith(status: FormStatus.succeeded));
      case Err<String>(:final AppFailure failure):
        emit(state.copyWith(status: FormStatus.editing, error: failure.message));
    }
  }
}
