import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../device_policy/domain/entities/policy.dart';
import '../../../../device_policy/presentation/editing/policy_section_editor.dart';
import '../../../../device_policy/presentation/editing/policy_section_state.dart';
import '../../../domain/services/app_rules_editing.dart';

part 'app_management_event.dart';
part 'app_management_state.dart';

/// Aplicativos permitidos, bloqueados e excecoes de um aparelho.
///
/// O ciclo de carregar, salvar, conflito e versao do servidor fica no [PolicySectionEditor];
/// as regras de edicao (estado efetivo, regra redundante, apps novos), em
/// `app_rules_editing.dart`.
class AppManagementBloc extends Bloc<AppManagementEvent, AppManagementState> {
  AppManagementBloc({required this._editor}) : super(const PolicySectionLoading<AppsPolicy>()) {
    on<AppManagementStarted>(_onStarted, transformer: restartable());
    on<_AppManagementServerVersionChanged>(_onServerVersionChanged, transformer: restartable());
    on<AppRuleChanged>(
      (AppRuleChanged event, Emitter<AppManagementState> emit) => _edit(
        emit,
        (AppsPolicy apps) =>
            setAppRule(apps, event.app.package, event.rule, system: event.app.system),
      ),
    );
    on<AppRulesAppliedToMany>(
      (AppRulesAppliedToMany event, Emitter<AppManagementState> emit) =>
          _edit(emit, (AppsPolicy apps) => setStateForMany(apps, event.apps, event.state)),
    );
    on<NewAppDefaultChanged>(
      (NewAppDefaultChanged event, Emitter<AppManagementState> emit) => _edit(
        emit,
        (AppsPolicy apps) => setNewAppDefault(apps, event.value, knownApps: event.installedApps),
      ),
    );
    on<AppManagementSaveRequested>(_onSaveRequested, transformer: droppable());
    on<AppManagementDiscardRequested>(
      (AppManagementDiscardRequested event, Emitter<AppManagementState> emit) =>
          emit(_editor.discard(state)),
    );
  }

  final PolicySectionEditor<AppsPolicy> _editor;

  Future<void> _onStarted(AppManagementStarted event, Emitter<AppManagementState> emit) async {
    emit(const PolicySectionLoading<AppsPolicy>());
    emit(await _editor.load(event.deviceId));
    await emit.onEach<int>(
      _editor.serverVersions(event.deviceId),
      onData: (int version) => add(_AppManagementServerVersionChanged(version)),
    );
  }

  Future<void> _onServerVersionChanged(
    _AppManagementServerVersionChanged event,
    Emitter<AppManagementState> emit,
  ) async {
    final AppManagementState? next = await _editor.follow(state, event.version);
    if (next != null) {
      emit(next);
    }
  }

  void _edit(Emitter<AppManagementState> emit, AppsPolicy Function(AppsPolicy apps) change) {
    emit(_editor.edit(state, change));
  }

  Future<void> _onSaveRequested(
    AppManagementSaveRequested event,
    Emitter<AppManagementState> emit,
  ) async {
    final PolicySectionEditing<AppsPolicy>? saving = _editor.startSaving(state);
    if (saving == null) {
      return;
    }
    emit(saving);
    emit(await _editor.save(saving));
  }
}
