import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../device_policy/presentation/editing/policy_section_editor.dart';
import '../../../../device_policy/presentation/editing/policy_section_state.dart';
import '../../../domain/entities/block_period_draft.dart';
import '../../../domain/entities/block_period_suggestion.dart';
import '../../../domain/entities/day_window.dart';
import '../../../domain/entities/schedule_rules.dart';
import '../../../domain/services/allowed_hours_editing.dart';
import '../../../domain/services/block_period_editing.dart';
import '../../../domain/services/period_ids.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

/// Horarios e regras programadas de um aparelho: horarios permitidos por dia da semana e
/// periodos de bloqueio.
///
/// O ciclo de carregar, salvar, conflito e versao do servidor fica no [PolicySectionEditor];
/// as regras de edicao, nos servicos de dominio. Os identificadores dos periodos novos vem do
/// gerador recebido, para os testes poderem fixa-los.
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  ScheduleBloc({required this._editor, this._newId = newUuid})
    : super(const PolicySectionLoading<ScheduleRules>()) {
    on<ScheduleStarted>(_onStarted, transformer: restartable());
    on<_ScheduleServerVersionChanged>(_onServerVersionChanged, transformer: restartable());
    on<AllowedHoursToggled>(
      (AllowedHoursToggled event, Emitter<ScheduleState> emit) => _edit(
        emit,
        (ScheduleRules rules) => rules.copyWith(
          allowedHours: withAllowedHoursEnabled(rules.allowedHours, event.enabled),
        ),
      ),
    );
    on<AllowedHoursWindowAdded>(
      (AllowedHoursWindowAdded event, Emitter<ScheduleState> emit) =>
          _editWeek(emit, (WeekWindows week) => addDayWindow(week, event.weekday, event.window)),
    );
    on<AllowedHoursWindowRemoved>(
      (AllowedHoursWindowRemoved event, Emitter<ScheduleState> emit) =>
          _editWeek(emit, (WeekWindows week) => removeDayWindow(week, event.weekday, event.window)),
    );
    on<AllowedHoursDayCopiedToAll>(
      (AllowedHoursDayCopiedToAll event, Emitter<ScheduleState> emit) => _editWeek(
        emit,
        (WeekWindows week) =>
            copyDayWindows(week, from: event.weekday, to: const <int>[1, 2, 3, 4, 5, 6, 7]),
      ),
    );
    on<BlockPeriodSaved>(_onBlockPeriodSaved);
    on<BlockPeriodDeleted>(
      (BlockPeriodDeleted event, Emitter<ScheduleState> emit) => _edit(
        emit,
        (ScheduleRules rules) => rules.copyWith(
          blockPeriods: BlockPeriodEditing.remove(rules.blockPeriods, event.periodId),
        ),
      ),
    );
    on<BlockPeriodToggled>(
      (BlockPeriodToggled event, Emitter<ScheduleState> emit) => _edit(
        emit,
        (ScheduleRules rules) => rules.copyWith(
          blockPeriods: BlockPeriodEditing.setEnabled(
            rules.blockPeriods,
            event.periodId,
            event.enabled,
          ),
        ),
      ),
    );
    on<BlockPeriodSuggestionAdded>(
      (BlockPeriodSuggestionAdded event, Emitter<ScheduleState> emit) => _edit(
        emit,
        (ScheduleRules rules) => rules.copyWith(
          blockPeriods: BlockPeriodEditing.upsert(
            rules.blockPeriods,
            event.suggestion.toPeriod(_newId()),
          ),
        ),
      ),
    );
    on<ScheduleSaveRequested>(_onSaveRequested, transformer: droppable());
    on<ScheduleDiscardRequested>(
      (ScheduleDiscardRequested event, Emitter<ScheduleState> emit) => emit(_editor.discard(state)),
    );
  }

  final PolicySectionEditor<ScheduleRules> _editor;
  final PeriodIdGenerator _newId;

  Future<void> _onStarted(ScheduleStarted event, Emitter<ScheduleState> emit) async {
    emit(const PolicySectionLoading<ScheduleRules>());
    emit(await _editor.load(event.deviceId));
    await emit.onEach<int>(
      _editor.serverVersions(event.deviceId),
      onData: (int version) => add(_ScheduleServerVersionChanged(version)),
    );
  }

  Future<void> _onServerVersionChanged(
    _ScheduleServerVersionChanged event,
    Emitter<ScheduleState> emit,
  ) async {
    final ScheduleState? next = await _editor.follow(state, event.version);
    if (next != null) {
      emit(next);
    }
  }

  void _onBlockPeriodSaved(BlockPeriodSaved event, Emitter<ScheduleState> emit) {
    if (event.draft.problem != null) {
      return;
    }
    final String id = event.draft.id ?? _newId();
    _edit(
      emit,
      (ScheduleRules rules) => rules.copyWith(
        blockPeriods: BlockPeriodEditing.upsert(rules.blockPeriods, event.draft.toPeriod(id)),
      ),
    );
  }

  void _edit(Emitter<ScheduleState> emit, ScheduleRules Function(ScheduleRules rules) change) {
    emit(_editor.edit(state, change));
  }

  void _editWeek(Emitter<ScheduleState> emit, WeekWindows Function(WeekWindows week) change) {
    _edit(
      emit,
      (ScheduleRules rules) => rules.copyWith(allowedHours: editWeek(rules.allowedHours, change)),
    );
  }

  Future<void> _onSaveRequested(ScheduleSaveRequested event, Emitter<ScheduleState> emit) async {
    final PolicySectionEditing<ScheduleRules>? saving = _editor.startSaving(state);
    if (saving == null) {
      return;
    }
    emit(saving);
    emit(await _editor.save(saving));
  }
}
