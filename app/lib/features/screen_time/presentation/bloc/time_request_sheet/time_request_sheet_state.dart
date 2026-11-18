part of 'time_request_sheet_bloc.dart';

final class TimeRequestSheetState extends Equatable {
  const TimeRequestSheetState({
    this.minutes = TimeRequestSheetBloc.defaultMinutes,
    this.status = FormStatus.editing,
    this.error,
  });

  /// Tempo escolhido, em minutos.
  final int minutes;
  final FormStatus status;

  /// Motivo da recusa do envio.
  final String? error;

  TimeRequestSheetState copyWith({int? minutes, FormStatus? status, String? error}) {
    return TimeRequestSheetState(
      minutes: minutes ?? this.minutes,
      status: status ?? this.status,
      error: error,
    );
  }

  @override
  List<Object?> get props => <Object?>[minutes, status, error];
}
