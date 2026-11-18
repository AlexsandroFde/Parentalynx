import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../device_policy/domain/entities/policy.dart';
import '../../../../device_policy/presentation/editing/policy_section_editor.dart';
import '../../../../device_policy/presentation/editing/policy_section_state.dart';
import '../../../domain/services/web_policy_editing.dart';

part 'web_filter_event.dart';
part 'web_filter_state.dart';

/// Regras de navegacao na internet: navegador gerenciado, filtros e listas de sites.
///
/// O ciclo de carregar, salvar, conflito e versao do servidor fica no [PolicySectionEditor];
/// as regras das listas e categorias, em [WebPolicyEditing].
class WebFilterBloc extends Bloc<WebFilterEvent, WebFilterState> {
  WebFilterBloc({required this._editor}) : super(const PolicySectionLoading<WebPolicy>()) {
    on<WebFilterStarted>(_onStarted, transformer: restartable());
    on<_WebFilterServerVersionChanged>(_onServerVersionChanged, transformer: restartable());
    on<WebManagedBrowserChanged>(
      (WebManagedBrowserChanged event, Emitter<WebFilterState> emit) =>
          _edit(emit, (WebPolicy web) => web.copyWith(managedBrowser: event.enabled)),
    );
    on<WebHistoryLoggingChanged>(
      (WebHistoryLoggingChanged event, Emitter<WebFilterState> emit) =>
          _edit(emit, (WebPolicy web) => web.copyWith(logHistory: event.enabled)),
    );
    on<WebSafeSearchChanged>(
      (WebSafeSearchChanged event, Emitter<WebFilterState> emit) =>
          _edit(emit, (WebPolicy web) => web.copyWith(safeSearch: event.enabled)),
    );
    on<WebSafeDnsChanged>(
      (WebSafeDnsChanged event, Emitter<WebFilterState> emit) =>
          _edit(emit, (WebPolicy web) => web.copyWith(safeDns: event.enabled)),
    );
    on<WebModeChanged>(
      (WebModeChanged event, Emitter<WebFilterState> emit) =>
          _edit(emit, (WebPolicy web) => web.copyWith(mode: event.mode)),
    );
    on<WebCategoryToggled>(
      (WebCategoryToggled event, Emitter<WebFilterState> emit) => _edit(
        emit,
        (WebPolicy web) =>
            WebPolicyEditing.withCategory(web, event.category, blocked: event.blocked),
      ),
    );
    on<WebDomainAdded>(
      (WebDomainAdded event, Emitter<WebFilterState> emit) =>
          _edit(emit, (WebPolicy web) => WebPolicyEditing.addDomain(web, event.list, event.domain)),
    );
    on<WebDomainRemoved>(
      (WebDomainRemoved event, Emitter<WebFilterState> emit) => _edit(
        emit,
        (WebPolicy web) => WebPolicyEditing.removeDomain(web, event.list, event.domain),
      ),
    );
    on<WebFilterSaveRequested>(_onSaveRequested, transformer: droppable());
    on<WebFilterDiscardRequested>(
      (WebFilterDiscardRequested event, Emitter<WebFilterState> emit) =>
          emit(_editor.discard(state)),
    );
  }

  final PolicySectionEditor<WebPolicy> _editor;

  Future<void> _onStarted(WebFilterStarted event, Emitter<WebFilterState> emit) async {
    emit(const PolicySectionLoading<WebPolicy>());
    emit(await _editor.load(event.deviceId));
    await emit.onEach<int>(
      _editor.serverVersions(event.deviceId),
      onData: (int version) => add(_WebFilterServerVersionChanged(version)),
    );
  }

  Future<void> _onServerVersionChanged(
    _WebFilterServerVersionChanged event,
    Emitter<WebFilterState> emit,
  ) async {
    final WebFilterState? next = await _editor.follow(state, event.version);
    if (next != null) {
      emit(next);
    }
  }

  void _edit(Emitter<WebFilterState> emit, WebPolicy Function(WebPolicy web) change) {
    emit(_editor.edit(state, change));
  }

  Future<void> _onSaveRequested(WebFilterSaveRequested event, Emitter<WebFilterState> emit) async {
    final PolicySectionEditing<WebPolicy>? saving = _editor.startSaving(state);
    if (saving == null) {
      return;
    }
    emit(saving);
    emit(await _editor.save(saving));
  }
}
