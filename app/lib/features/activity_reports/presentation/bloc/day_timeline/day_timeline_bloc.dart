import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/time/clock.dart';
import '../../../../../core/time/formatters.dart';
import '../../../domain/entities/day_timeline.dart';
import '../../../domain/entities/report_period.dart';
import '../../../domain/usecases/get_day_timeline.dart';

part 'day_timeline_event.dart';
part 'day_timeline_state.dart';

/// Linha do tempo das sessoes de um dia, com a navegacao entre os dias.
class DayTimelineBloc extends Bloc<DayTimelineEvent, DayTimelineState> {
  DayTimelineBloc({required this._getDayTimeline, required this._clock})
    : super(const DayTimelineInitial()) {
    on<DayTimelineEvent>(_onEvent, transformer: restartable());
  }

  final GetDayTimeline _getDayTimeline;
  final Clock _clock;
  String? _deviceId;

  Future<void> _onEvent(DayTimelineEvent event, Emitter<DayTimelineState> emit) async {
    if (event is DayTimelineRefreshRequested) {
      await _refresh(event, emit);
      return;
    }
    final String day;
    final String today;
    switch (event) {
      case DayTimelineStarted(
        :final String deviceId,
        :final String deviceToday,
        :final String? initialDay,
      ):
        _deviceId = deviceId;
        today = quotaDayOf(deviceToday, _clock.now());
        day = initialDay ?? today;
      case DayTimelinePreviousDayRequested():
        today = state.today;
        day = addDays(state.day, -1);
      case DayTimelineNextDayRequested():
        if (!state.canGoForward) {
          return;
        }
        today = state.today;
        day = addDays(state.day, 1);
      case DayTimelineDaySelected(day: final String picked):
        today = state.today;
        day = picked.compareTo(today) > 0 ? today : picked;
      case DayTimelineRetried() || DayTimelineRefreshRequested():
        today = state.today;
        day = state.day;
    }
    final String? deviceId = _deviceId;
    if (deviceId == null) {
      return;
    }
    emit(DayTimelineLoading(day: day, today: today));
    final Result<DayTimeline> result = await _getDayTimeline(deviceId, day: day);
    emit(_stateOf(result, day: day, today: today));
  }

  /// Busca de novo o dia mostrado. Uma falha mantem a linha do tempo que ja estava na tela.
  Future<void> _refresh(DayTimelineRefreshRequested event, Emitter<DayTimelineState> emit) async {
    final String? deviceId = _deviceId;
    final DayTimelineState current = state;
    if (deviceId == null || current is DayTimelineInitial) {
      event.completer?.complete(null);
      return;
    }
    final Result<DayTimeline> result = await _getDayTimeline(deviceId, day: current.day);
    final AppFailure? failure = result is Err<DayTimeline> ? result.failure : null;
    final bool showing = current is DayTimelineLoaded || current is DayTimelineEmpty;
    if (failure == null || !showing) {
      emit(_stateOf(result, day: current.day, today: current.today));
    }
    event.completer?.complete(failure);
  }

  static DayTimelineState _stateOf(
    Result<DayTimeline> result, {
    required String day,
    required String today,
  }) {
    return switch (result) {
      Ok<DayTimeline>(:final DayTimeline value) =>
        value.isEmpty
            ? DayTimelineEmpty(day: day, today: today)
            : DayTimelineLoaded(day: day, today: today, timeline: value),
      Err<DayTimeline>(:final AppFailure failure) => DayTimelineError(
        day: day,
        today: today,
        failure: failure,
      ),
    };
  }
}
