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
      case DayTimelineRetried():
        today = state.today;
        day = state.day;
    }
    final String? deviceId = _deviceId;
    if (deviceId == null) {
      return;
    }
    emit(DayTimelineLoading(day: day, today: today));
    final Result<DayTimeline> result = await _getDayTimeline(deviceId, day: day);
    switch (result) {
      case Ok<DayTimeline>(:final DayTimeline value):
        emit(
          value.isEmpty
              ? DayTimelineEmpty(day: day, today: today)
              : DayTimelineLoaded(day: day, today: today, timeline: value),
        );
      case Err<DayTimeline>(:final AppFailure failure):
        emit(DayTimelineError(day: day, today: today, failure: failure));
    }
  }
}
