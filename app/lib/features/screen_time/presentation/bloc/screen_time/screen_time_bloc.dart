import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../device_policy/domain/entities/policy.dart';
import '../../../../device_policy/presentation/editing/policy_section_editor.dart';
import '../../../../device_policy/presentation/editing/policy_section_state.dart';
import '../../../domain/services/daily_limit_editing.dart';

part 'screen_time_event.dart';
part 'screen_time_state.dart';

/// Limite diario de uso de um aparelho: tempo por dia, por dia da semana, reinicio da
/// contagem e avisos para a crianca.
///
/// O ciclo de carregar, salvar, conflito e versao do servidor e o mesmo de todas as secoes da
/// politica e fica no [PolicySectionEditor]. Este BLoC traduz as intencoes da tela em
/// alteracoes do limite, cujas regras ficam na entidade e nos servicos de dominio.
class ScreenTimeBloc extends Bloc<ScreenTimeEvent, ScreenTimeState> {
  ScreenTimeBloc({required this._editor}) : super(const PolicySectionLoading<DailyLimit>()) {
    on<ScreenTimeStarted>(_onStarted, transformer: restartable());
    on<_ScreenTimeServerVersionChanged>(_onServerVersionChanged, transformer: restartable());
    on<DailyLimitEnabledChanged>(
      (DailyLimitEnabledChanged event, Emitter<ScreenTimeState> emit) =>
          _edit(emit, (DailyLimit limit) => limit.copyWith(enabled: event.enabled)),
    );
    on<DailyLimitMinutesChanged>(
      (DailyLimitMinutesChanged event, Emitter<ScreenTimeState> emit) =>
          _edit(emit, (DailyLimit limit) => limit.copyWith(minutes: event.minutes)),
    );
    on<DailyLimitPerWeekdayToggled>(
      (DailyLimitPerWeekdayToggled event, Emitter<ScreenTimeState> emit) =>
          _edit(emit, (DailyLimit limit) => limit.withPerWeekday(event.enabled)),
    );
    on<DailyLimitWeekdayMinutesChanged>(
      (DailyLimitWeekdayMinutesChanged event, Emitter<ScreenTimeState> emit) =>
          _edit(emit, (DailyLimit limit) => limit.withDayMinutes(event.weekday, event.minutes)),
    );
    on<DailyLimitResetTimeChanged>(
      (DailyLimitResetTimeChanged event, Emitter<ScreenTimeState> emit) =>
          _edit(emit, (DailyLimit limit) => limit.copyWith(resetTime: event.resetTime)),
    );
    on<DailyLimitWarningToggled>(
      (DailyLimitWarningToggled event, Emitter<ScreenTimeState> emit) => _edit(
        emit,
        (DailyLimit limit) => limit.withWarning(event.minutes, enabled: event.enabled),
      ),
    );
    on<ScreenTimeSaveRequested>(_onSaveRequested, transformer: droppable());
    on<ScreenTimeRejectedChangesRestored>(
      (ScreenTimeRejectedChangesRestored event, Emitter<ScreenTimeState> emit) =>
          emit(_editor.restoreRejected(state)),
    );
    on<ScreenTimeDiscardRequested>(
      (ScreenTimeDiscardRequested event, Emitter<ScreenTimeState> emit) =>
          emit(_editor.discard(state)),
    );
  }

  final PolicySectionEditor<DailyLimit> _editor;

  Future<void> _onStarted(ScreenTimeStarted event, Emitter<ScreenTimeState> emit) async {
    emit(const PolicySectionLoading<DailyLimit>());
    emit(await _editor.load(event.deviceId));
    await emit.onEach<int>(
      _editor.serverVersions(event.deviceId),
      onData: (int version) => add(_ScreenTimeServerVersionChanged(version)),
    );
  }

  Future<void> _onServerVersionChanged(
    _ScreenTimeServerVersionChanged event,
    Emitter<ScreenTimeState> emit,
  ) async {
    final ScreenTimeState? next = await _editor.follow(state, event.version);
    if (next != null) {
      emit(next);
    }
  }

  void _edit(Emitter<ScreenTimeState> emit, DailyLimit Function(DailyLimit limit) change) {
    emit(_editor.edit(state, change));
  }

  Future<void> _onSaveRequested(
    ScreenTimeSaveRequested event,
    Emitter<ScreenTimeState> emit,
  ) async {
    final PolicySectionEditing<DailyLimit>? saving = _editor.startSaving(state);
    if (saving == null) {
      return;
    }
    emit(saving);
    emit(await _editor.save(saving));
  }
}
