import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../app_management/domain/entities/allowed_app.dart';
import '../../../../app_management/domain/usecases/launch_allowed_app.dart';
import '../../../../device_sync/domain/entities/device_sync_result.dart';
import '../../../../device_sync/domain/usecases/trigger_device_sync.dart';
import '../../../../managed_browser/domain/usecases/open_managed_browser.dart';
import '../../../domain/entities/child_home_summary.dart';
import '../../../domain/usecases/load_child_home_summary.dart';
import '../../services/foreground_tracker.dart';
import '../../texts/home_texts.dart';

part 'child_home_event.dart';
part 'child_home_state.dart';

/// Tela inicial da crianca: dados que mudam devagar (regras, uso por app, apps liberados e
/// pedidos de tempo), atualizados a cada [refreshInterval] com o app em primeiro plano, e os
/// comandos da tela (sincronizar, abrir o navegador seguro, abrir um app liberado).
///
/// O retrato do agente (tempo restante, bloqueio) vem do `ChildDeviceStatusBloc`.
class ChildHomeBloc extends Bloc<ChildHomeEvent, ChildHomeState> {
  ChildHomeBloc({
    required this._loadSummary,
    required this._triggerDeviceSync,
    required this._openManagedBrowser,
    required this._launchAllowedApp,
    required this._foreground,
    this.refreshInterval = const Duration(seconds: 15),
  }) : super(const ChildHomeState()) {
    on<ChildHomeStarted>(_onStarted, transformer: droppable());
    on<ChildHomeRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<ChildHomeSyncRequested>(_onSyncRequested, transformer: droppable());
    on<ChildHomeBrowserRequested>(_onBrowserRequested, transformer: droppable());
    on<ChildHomeAppLaunchRequested>(_onAppLaunchRequested, transformer: droppable());
    on<ChildHomeTimeRequestSent>(_onTimeRequestSent, transformer: droppable());
  }

  final LoadChildHomeSummary _loadSummary;
  final TriggerDeviceSync _triggerDeviceSync;
  final OpenManagedBrowser _openManagedBrowser;
  final LaunchAllowedApp _launchAllowedApp;
  final ForegroundTracker _foreground;

  /// Intervalo de atualizacao dos dados que mudam devagar.
  final Duration refreshInterval;

  Timer? _timer;

  Future<void> _onStarted(ChildHomeStarted event, Emitter<ChildHomeState> emit) async {
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (Timer timer) {
      if (_foreground.isForeground) {
        add(const ChildHomeRefreshRequested());
      }
    });
    await _reload(emit);
  }

  Future<void> _onRefreshRequested(ChildHomeRefreshRequested event, Emitter<ChildHomeState> emit) {
    return _reload(emit);
  }

  Future<void> _onSyncRequested(ChildHomeSyncRequested event, Emitter<ChildHomeState> emit) async {
    emit(state.copyWith(syncing: true).withNotice(null));
    final Result<DeviceSyncResult> result = await _triggerDeviceSync();
    final HomeNotice notice;
    switch (result) {
      case Ok<DeviceSyncResult>(value: final DeviceSyncResult outcome):
        // Regras novas podem ter chegado: o resumo e relido antes do aviso.
        await _reload(emit);
        notice = HomeNotice(
          kind: outcome.ok ? HomeNoticeKind.success : HomeNoticeKind.warning,
          message: syncResultMessage(outcome),
        );
      case Err<DeviceSyncResult>(:final AppFailure failure):
        notice = HomeNotice.failure(failure);
    }
    emit(state.copyWith(syncing: false).withNotice(notice));
  }

  Future<void> _onBrowserRequested(
    ChildHomeBrowserRequested event,
    Emitter<ChildHomeState> emit,
  ) async {
    emit(state.withNotice(null));
    final Result<void> result = await _openManagedBrowser();
    if (result case Err<void>(:final AppFailure failure)) {
      emit(state.withNotice(HomeNotice.failure(failure)));
    }
  }

  Future<void> _onAppLaunchRequested(
    ChildHomeAppLaunchRequested event,
    Emitter<ChildHomeState> emit,
  ) async {
    emit(state.withNotice(null));
    final Result<bool> result = await _launchAllowedApp(event.app);
    switch (result) {
      case Ok<bool>(value: true):
        break;
      case Ok<bool>():
        emit(
          state.withNotice(
            HomeNotice(kind: HomeNoticeKind.warning, message: launchFailedMessage(event.app.label)),
          ),
        );
      case Err<bool>(:final AppFailure failure):
        emit(state.withNotice(HomeNotice.failure(failure)));
    }
  }

  Future<void> _onTimeRequestSent(
    ChildHomeTimeRequestSent event,
    Emitter<ChildHomeState> emit,
  ) async {
    emit(state.withNotice(null));
    emit(
      state.withNotice(
        const HomeNotice(kind: HomeNoticeKind.success, message: timeRequestSentMessage),
      ),
    );
    await _reload(emit);
  }

  /// Recarrega mantendo o que esta na tela se a consulta falhar.
  Future<void> _reload(Emitter<ChildHomeState> emit) async {
    final Result<ChildHomeSummary> result = await _loadSummary();
    if (result case Ok<ChildHomeSummary>(value: final ChildHomeSummary summary)) {
      emit(state.copyWith(summary: summary));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
