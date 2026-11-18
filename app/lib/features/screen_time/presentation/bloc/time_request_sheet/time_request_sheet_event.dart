part of 'time_request_sheet_bloc.dart';

sealed class TimeRequestSheetEvent extends Equatable {
  const TimeRequestSheetEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A folha abriu: comeca um pedido novo.
final class TimeRequestSheetOpened extends TimeRequestSheetEvent {
  const TimeRequestSheetOpened();
}

/// A crianca escolheu quanto tempo pedir.
final class TimeRequestMinutesSelected extends TimeRequestSheetEvent {
  const TimeRequestMinutesSelected(this.minutes);

  final int minutes;

  @override
  List<Object?> get props => <Object?>[minutes];
}

/// A crianca tocou em "Enviar pedido".
final class TimeRequestSheetSubmitted extends TimeRequestSheetEvent {
  const TimeRequestSheetSubmitted({this.message});

  final String? message;

  @override
  List<Object?> get props => <Object?>[message];
}
