import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/time/clock.dart';
import '../../../../../core/time/formatters.dart';
import '../../../../app_management/domain/entities/app_entry.dart';
import '../../../../app_management/domain/usecases/get_device_apps.dart';
import '../../../../blocking/domain/usecases/lock_device_now.dart';
import '../../../../blocking/domain/usecases/resume_rules.dart';
import '../../../../blocking/domain/usecases/suspend_rules.dart';
import '../../../../blocking/domain/usecases/unlock_device.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../../child_device/domain/usecases/watch_child_devices.dart';
import '../../../../device_policy/domain/entities/policy.dart';
import '../../../../device_policy/domain/entities/versioned_policy.dart';
import '../../../../device_policy/domain/usecases/get_device_policy.dart';
import '../../../../device_sync/domain/entities/policy_sync_status.dart';
import '../../../../notifications/domain/entities/guardian_alert.dart';
import '../../../../notifications/domain/usecases/get_recent_alerts.dart';
import '../../../../notifications/domain/usecases/watch_incoming_alerts.dart';
import '../../../../screen_time/domain/usecases/grant_additional_time.dart';
import '../../../domain/entities/active_commands.dart';
import '../../../domain/entities/device_connection.dart';
import '../../../domain/entities/today_usage.dart';
import 'panel_state.dart';

part 'guardian_dashboard_event.dart';
part 'guardian_dashboard_state.dart';

/// Informacoes gerais do responsavel sobre o aparelho em foco: estado, tempo de hoje,
/// comandos em vigor, apps mais usados e alertas recentes, e as acoes rapidas.
///
/// Acompanha o aparelho pela lista da conta: quando ele sincroniza, os apps sao recarregados;
/// quando a politica ganha versao nova, ela tambem. Os comandos devolvem a politica nova, que
/// passa a valer na hora.
class GuardianDashboardBloc extends Bloc<GuardianDashboardEvent, GuardianDashboardState> {
  GuardianDashboardBloc({
    required this._watchDevices,
    required this._getDevicePolicy,
    required this._getDeviceApps,
    required this._getRecentAlerts,
    required this._incomingAlerts,
    required this._grantAdditionalTime,
    required this._lockDeviceNow,
    required this._unlockDevice,
    required this._suspendRules,
    required this._resumeRules,
    required this._clock,
  }) : super(const GuardianDashboardState()) {
    on<DashboardDeviceSelected>(_onDeviceSelected, transformer: restartable());
    on<_DashboardDeviceChanged>(_onDeviceChanged, transformer: sequential());
    on<_DashboardPolicyReloadRequested>((
      _DashboardPolicyReloadRequested event,
      Emitter<GuardianDashboardState> emit,
    ) {
      return _loadPolicy(emit);
    }, transformer: restartable());
    on<_DashboardAppsReloadRequested>((
      _DashboardAppsReloadRequested event,
      Emitter<GuardianDashboardState> emit,
    ) {
      return _loadApps(emit);
    }, transformer: restartable());
    on<_DashboardAlertsReloadRequested>((
      _DashboardAlertsReloadRequested event,
      Emitter<GuardianDashboardState> emit,
    ) {
      return _loadAlerts(emit);
    }, transformer: restartable());
    on<DashboardRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<DashboardExtraTimeRequested>(_onExtraTime, transformer: droppable());
    on<DashboardPauseRequested>(_onPause, transformer: droppable());
    on<DashboardResumeRequested>(_onResume, transformer: droppable());
    on<DashboardSuspendRequested>(_onSuspend, transformer: droppable());
    on<DashboardSuspensionEndRequested>(_onSuspensionEnd, transformer: droppable());
  }

  final WatchChildDevices _watchDevices;
  final GetDevicePolicy _getDevicePolicy;
  final GetDeviceApps _getDeviceApps;
  final GetRecentAlerts _getRecentAlerts;
  final WatchIncomingAlerts _incomingAlerts;
  final GrantAdditionalTime _grantAdditionalTime;
  final LockDeviceNow _lockDeviceNow;
  final UnlockDevice _unlockDevice;
  final SuspendRules _suspendRules;
  final ResumeRules _resumeRules;
  final Clock _clock;

  Future<void> _onDeviceSelected(
    DashboardDeviceSelected event,
    Emitter<GuardianDashboardState> emit,
  ) async {
    if (state.deviceId != event.deviceId) {
      emit(GuardianDashboardState(deviceId: event.deviceId));
      add(const _DashboardPolicyReloadRequested());
      add(const _DashboardAppsReloadRequested());
      add(const _DashboardAlertsReloadRequested());
    }
    await Future.wait(<Future<void>>[
      emit.onEach<ChildDevice?>(
        _watchDevices.device(event.deviceId),
        onData: (ChildDevice? device) => add(_DashboardDeviceChanged(device)),
      ),
      // Um alerta novo muda a previa de alertas recentes.
      emit.onEach<GuardianAlert>(
        _incomingAlerts(),
        onData: (GuardianAlert alert) => add(const _DashboardAlertsReloadRequested()),
      ),
    ]);
  }

  void _onDeviceChanged(_DashboardDeviceChanged event, Emitter<GuardianDashboardState> emit) {
    final ChildDevice? device = event.device;
    if (device == null || device.id != state.deviceId) {
      return;
    }
    final ChildDevice? previous = state.device;
    emit(
      state.copyWith(
        device: device,
        connection: DeviceConnection.of(device, nowMs: _clock.nowMs()),
        commands: _commandsFor(state.policy.valueOrNull, device),
      ),
    );
    // O aparelho sincronizou de novo: os tempos dos apps mudaram.
    if (previous != null && previous.lastSyncAt != device.lastSyncAt) {
      add(const _DashboardAppsReloadRequested());
    }
    // Versao nova da politica no servidor (comando de outra sessao, regras salvas).
    final VersionedPolicy? policy = state.policy.valueOrNull;
    if (policy != null && device.policyVersion > policy.version) {
      add(const _DashboardPolicyReloadRequested());
    }
  }

  Future<void> _onRefreshRequested(
    DashboardRefreshRequested event,
    Emitter<GuardianDashboardState> emit,
  ) async {
    try {
      await Future.wait(<Future<void>>[_loadApps(emit), _loadAlerts(emit), _loadPolicy(emit)]);
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _loadPolicy(Emitter<GuardianDashboardState> emit) async {
    final String? deviceId = state.deviceId;
    if (deviceId == null) {
      return;
    }
    final Result<VersionedPolicy> result = await _getDevicePolicy(deviceId);
    if (state.deviceId != deviceId) {
      return;
    }
    switch (result) {
      case Ok<VersionedPolicy>(:final VersionedPolicy value):
        final VersionedPolicy? current = state.policy.valueOrNull;
        // Uma resposta atrasada nao substitui uma versao mais nova ja recebida.
        if (current != null && value.version < current.version) {
          return;
        }
        _adoptPolicy(emit, value);
      case Err<VersionedPolicy>(:final AppFailure failure):
        if (state.policy is! PanelLoaded<VersionedPolicy>) {
          emit(state.copyWith(policy: PanelFailed<VersionedPolicy>(failure)));
        }
    }
  }

  Future<void> _loadApps(Emitter<GuardianDashboardState> emit) async {
    final String? deviceId = state.deviceId;
    if (deviceId == null) {
      return;
    }
    final Result<DeviceApps> result = await _getDeviceApps(deviceId);
    if (state.deviceId != deviceId) {
      return;
    }
    switch (result) {
      case Ok<DeviceApps>(:final DeviceApps value):
        emit(state.copyWith(apps: PanelLoaded<DeviceApps>(value)));
      case Err<DeviceApps>(:final AppFailure failure):
        if (state.apps is! PanelLoaded<DeviceApps>) {
          emit(state.copyWith(apps: PanelFailed<DeviceApps>(failure)));
        }
    }
  }

  Future<void> _loadAlerts(Emitter<GuardianDashboardState> emit) async {
    final Result<List<GuardianAlert>> result = await _getRecentAlerts();
    switch (result) {
      case Ok<List<GuardianAlert>>(:final List<GuardianAlert> value):
        emit(state.copyWith(recentAlerts: PanelLoaded<List<GuardianAlert>>(value)));
      case Err<List<GuardianAlert>>(:final AppFailure failure):
        if (state.recentAlerts is! PanelLoaded<List<GuardianAlert>>) {
          emit(state.copyWith(recentAlerts: PanelFailed<List<GuardianAlert>>(failure)));
        }
    }
  }

  Future<void> _onExtraTime(
    DashboardExtraTimeRequested event,
    Emitter<GuardianDashboardState> emit,
  ) {
    return _runCommand(
      emit,
      DashboardCommand(DashboardCommandKind.extraTime, minutes: event.minutes),
      (String deviceId) => _grantAdditionalTime(deviceId, minutes: event.minutes),
      (ChildDevice device) =>
          '${formatMinutes(event.minutes)} a mais para hoje. ${_delivery(device)}',
    );
  }

  Future<void> _onPause(DashboardPauseRequested event, Emitter<GuardianDashboardState> emit) {
    return _runCommand(
      emit,
      const DashboardCommand(DashboardCommandKind.pause),
      (String deviceId) => _lockDeviceNow(deviceId, duration: event.duration),
      (ChildDevice device) => 'Pausa salva. ${_delivery(device)}',
    );
  }

  Future<void> _onResume(DashboardResumeRequested event, Emitter<GuardianDashboardState> emit) {
    return _runCommand(
      emit,
      const DashboardCommand(DashboardCommandKind.resume),
      _unlockDevice.call,
      (ChildDevice device) => 'Pausa encerrada. ${_delivery(device)}',
    );
  }

  Future<void> _onSuspend(DashboardSuspendRequested event, Emitter<GuardianDashboardState> emit) {
    return _runCommand(
      emit,
      DashboardCommand(DashboardCommandKind.suspend, minutes: event.minutes),
      (String deviceId) => _suspendRules(deviceId, minutes: event.minutes, scopes: event.scopes),
      (ChildDevice device) =>
          'Regras suspensas por ${formatMinutes(event.minutes)}. ${_delivery(device)}',
    );
  }

  Future<void> _onSuspensionEnd(
    DashboardSuspensionEndRequested event,
    Emitter<GuardianDashboardState> emit,
  ) {
    return _runCommand(
      emit,
      const DashboardCommand(DashboardCommandKind.endSuspension),
      _resumeRules.call,
      (ChildDevice device) => 'Suspensão encerrada. ${_delivery(device)}',
    );
  }

  /// O comando fica salvo no servidor e so vale quando o aparelho receber. A mensagem diz
  /// isso, e avisa quando o aparelho esta sem conexao.
  static String _delivery(ChildDevice device) {
    return device.online
        ? 'O aparelho de ${device.displayName} recebe em instantes.'
        : 'O aparelho de ${device.displayName} está sem conexão e recebe quando voltar.';
  }

  /// Envia um comando ao aparelho em foco e adota a politica devolvida. Desistir do pedido de
  /// senha volta ao estado anterior sem aviso.
  Future<void> _runCommand(
    Emitter<GuardianDashboardState> emit,
    DashboardCommand which,
    Future<Result<VersionedPolicy>> Function(String deviceId) command,
    String Function(ChildDevice device) successMessage,
  ) async {
    final String? deviceId = state.deviceId;
    final ChildDevice? device = state.device;
    if (deviceId == null || device == null) {
      return;
    }
    emit(state.copyWith(command: const ActionRunning(), lastCommand: which));
    final Result<VersionedPolicy> result = await command(deviceId);
    switch (result) {
      case Ok<VersionedPolicy>(:final VersionedPolicy value):
        _adoptPolicy(emit, value, command: ActionSucceeded(message: successMessage(device)));
      case Err<VersionedPolicy>(:final AppFailure failure):
        emit(state.copyWith(command: actionStatusForFailure(failure)));
    }
  }

  void _adoptPolicy(
    Emitter<GuardianDashboardState> emit,
    VersionedPolicy policy, {
    ActionStatus? command,
  }) {
    emit(
      state.copyWith(
        policy: PanelLoaded<VersionedPolicy>(policy),
        commands: _commandsFor(policy, state.device),
        command: command,
      ),
    );
  }

  ActiveCommands _commandsFor(VersionedPolicy? policy, ChildDevice? device) {
    if (policy == null || device == null) {
      return ActiveCommands.none;
    }
    return ActiveCommands.of(policy.policy, nowMs: _clock.nowMs(), today: device.today);
  }
}
