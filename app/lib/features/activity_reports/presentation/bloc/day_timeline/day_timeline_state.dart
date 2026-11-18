part of 'day_timeline_bloc.dart';

/// Linha do tempo de um dia de um aparelho.
sealed class DayTimelineState extends Equatable {
  const DayTimelineState({required this.day, required this.today});

  /// Dia mostrado (AAAA-MM-DD).
  final String day;

  /// Dia da cota corrente do aparelho.
  final String today;

  /// O dia seguinte pode ser mostrado (nao passa do dia corrente).
  bool get canGoForward => day.compareTo(today) < 0;

  @override
  List<Object?> get props => <Object?>[day, today];
}

/// Ainda nao ha aparelho.
final class DayTimelineInitial extends DayTimelineState {
  const DayTimelineInitial() : super(day: '', today: '');
}

/// Buscando as sessoes do dia.
final class DayTimelineLoading extends DayTimelineState {
  const DayTimelineLoading({required super.day, required super.today});
}

/// O aparelho nao registrou uso neste dia.
final class DayTimelineEmpty extends DayTimelineState {
  const DayTimelineEmpty({required super.day, required super.today});
}

/// Sessoes do dia carregadas.
final class DayTimelineLoaded extends DayTimelineState {
  const DayTimelineLoaded({required super.day, required super.today, required this.timeline});

  final DayTimeline timeline;

  @override
  List<Object?> get props => <Object?>[day, today, timeline];
}

/// A consulta falhou. A tela oferece tentar de novo.
final class DayTimelineError extends DayTimelineState {
  const DayTimelineError({required super.day, required super.today, required this.failure});

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[day, today, failure];
}
