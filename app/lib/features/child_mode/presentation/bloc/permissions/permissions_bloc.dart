import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../device_linking/domain/usecases/finish_link_onboarding.dart';
import '../../../domain/entities/permission_plan.dart';
import '../../../domain/entities/permission_step.dart';
import '../../../domain/usecases/check_permissions.dart';
import '../../../domain/usecases/open_app_details_settings.dart';
import '../../../domain/usecases/open_permission_settings.dart';
import '../../texts/permission_texts.dart';

part 'permissions_event.dart';
part 'permissions_state.dart';

/// Assistente das permissoes de que o controle parental depende.
///
/// Cada permissao e concedida em uma tela do sistema, entao a tela pede a releitura
/// ([PermissionsRefreshRequested]) sempre que o app volta ao primeiro plano.
class PermissionsBloc extends Bloc<PermissionsEvent, PermissionsState> {
  PermissionsBloc({
    required this._checkPermissions,
    required this._openPermissionSettings,
    required this._openAppDetailsSettings,
    required this._finishLinkOnboarding,
  }) : super(const PermissionsLoading()) {
    on<PermissionsLoadRequested>(_onLoadRequested, transformer: restartable());
    on<PermissionsRefreshRequested>(_onRefreshRequested, transformer: restartable());
    on<PermissionsStepOpened>(_onStepOpened, transformer: droppable());
    on<PermissionsAppDetailsOpened>(_onAppDetailsOpened, transformer: droppable());
    on<PermissionsSetupFinished>(_onSetupFinished, transformer: droppable());
  }

  final CheckPermissions _checkPermissions;
  final OpenPermissionSettings _openPermissionSettings;
  final OpenAppDetailsSettings _openAppDetailsSettings;
  final FinishLinkOnboarding _finishLinkOnboarding;

  Future<void> _onLoadRequested(
    PermissionsLoadRequested event,
    Emitter<PermissionsState> emit,
  ) async {
    if (state is! PermissionsLoading) {
      emit(const PermissionsLoading());
    }
    final Result<PermissionPlan> result = await _checkPermissions();
    emit(switch (result) {
      Ok<PermissionPlan>(value: final PermissionPlan plan) => PermissionsLoaded(plan: plan),
      Err<PermissionPlan>(:final AppFailure failure) => PermissionsLoadFailure(failure),
    });
  }

  Future<void> _onRefreshRequested(
    PermissionsRefreshRequested event,
    Emitter<PermissionsState> emit,
  ) async {
    final PermissionsState current = state;
    if (current is! PermissionsLoaded) {
      add(const PermissionsLoadRequested());
      return;
    }
    final Result<PermissionPlan> result = await _checkPermissions(
      manufacturer: current.plan.manufacturer,
    );
    // Com falha, mantem o estado anterior. A proxima volta ao app tenta de novo.
    if (result case Ok<PermissionPlan>(value: final PermissionPlan plan)) {
      final PermissionsState now = state;
      if (now is PermissionsLoaded) {
        emit(now.copyWith(plan: plan));
      }
    }
  }

  Future<void> _onStepOpened(PermissionsStepOpened event, Emitter<PermissionsState> emit) async {
    final PermissionsState current = state;
    if (current is! PermissionsLoaded || current.opening != null) {
      return;
    }
    emit(current.startOpening(event.kind));
    final Result<PermissionActionResult> result = await _openPermissionSettings(event.kind);
    final PermissionsState now = state;
    if (now is! PermissionsLoaded) {
      return;
    }
    switch (result) {
      case Ok<PermissionActionResult>(value: PermissionActionResult.granted):
        emit(now.finished(const ActionSucceeded()));
        // Concedida na hora (dialogo do sistema): a tela ja mostra o passo ligado.
        add(const PermissionsRefreshRequested());
      case Ok<PermissionActionResult>(value: PermissionActionResult.fallbackToAppDetails):
        emit(now.finished(const ActionSucceeded(message: autostartFallbackMessage)));
      case Ok<PermissionActionResult>(value: PermissionActionResult.opened):
        emit(now.finished(const ActionSucceeded()));
      case Err<PermissionActionResult>(:final AppFailure failure):
        emit(now.finished(actionStatusForFailure(failure)));
    }
  }

  Future<void> _onAppDetailsOpened(
    PermissionsAppDetailsOpened event,
    Emitter<PermissionsState> emit,
  ) async {
    final Result<void> result = await _openAppDetailsSettings();
    final PermissionsState now = state;
    if (result case Err<void>(:final AppFailure failure) when now is PermissionsLoaded) {
      emit(now.copyWith(action: const ActionRunning()));
      emit(now.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  void _onSetupFinished(PermissionsSetupFinished event, Emitter<PermissionsState> emit) {
    // O roteador sai da configuracao inicial quando o vinculo fica pronto.
    _finishLinkOnboarding();
  }
}
