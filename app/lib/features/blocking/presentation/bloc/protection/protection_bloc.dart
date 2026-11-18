import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../device_policy/domain/entities/policy.dart';
import '../../../../device_policy/presentation/editing/policy_section_editor.dart';
import '../../../../device_policy/presentation/editing/policy_section_state.dart';
import '../../../domain/entities/system_lock.dart';

part 'protection_event.dart';
part 'protection_state.dart';

/// Protecao contra desativacao do controle: bloqueio por adulteracao e travas do sistema.
///
/// O ciclo de carregar, salvar, conflito e versao do servidor fica no [PolicySectionEditor].
class ProtectionBloc extends Bloc<ProtectionEvent, ProtectionState> {
  ProtectionBloc({required this._editor}) : super(const PolicySectionLoading<ProtectionPolicy>()) {
    on<ProtectionStarted>(_onStarted, transformer: restartable());
    on<_ProtectionServerVersionChanged>(_onServerVersionChanged, transformer: restartable());
    on<ProtectionLockOnTamperChanged>(
      (ProtectionLockOnTamperChanged event, Emitter<ProtectionState> emit) => _edit(
        emit,
        (ProtectionPolicy protection) => protection.copyWith(lockOnTamper: event.enabled),
      ),
    );
    on<ProtectionSystemLockChanged>(
      (ProtectionSystemLockChanged event, Emitter<ProtectionState> emit) =>
          _edit(emit, (ProtectionPolicy protection) => event.lock.apply(protection, event.enabled)),
    );
    on<ProtectionSaveRequested>(_onSaveRequested, transformer: droppable());
    on<ProtectionDiscardRequested>(
      (ProtectionDiscardRequested event, Emitter<ProtectionState> emit) =>
          emit(_editor.discard(state)),
    );
  }

  final PolicySectionEditor<ProtectionPolicy> _editor;

  Future<void> _onStarted(ProtectionStarted event, Emitter<ProtectionState> emit) async {
    emit(const PolicySectionLoading<ProtectionPolicy>());
    emit(await _editor.load(event.deviceId));
    await emit.onEach<int>(
      _editor.serverVersions(event.deviceId),
      onData: (int version) => add(_ProtectionServerVersionChanged(version)),
    );
  }

  Future<void> _onServerVersionChanged(
    _ProtectionServerVersionChanged event,
    Emitter<ProtectionState> emit,
  ) async {
    final ProtectionState? next = await _editor.follow(state, event.version);
    if (next != null) {
      emit(next);
    }
  }

  void _edit(
    Emitter<ProtectionState> emit,
    ProtectionPolicy Function(ProtectionPolicy protection) change,
  ) {
    emit(_editor.edit(state, change));
  }

  Future<void> _onSaveRequested(
    ProtectionSaveRequested event,
    Emitter<ProtectionState> emit,
  ) async {
    final PolicySectionEditing<ProtectionPolicy>? saving = _editor.startSaving(state);
    if (saving == null) {
      return;
    }
    emit(saving);
    emit(await _editor.save(saving));
  }
}
