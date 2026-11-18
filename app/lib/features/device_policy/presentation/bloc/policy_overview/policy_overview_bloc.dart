import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../../child_device/domain/usecases/refresh_child_devices.dart';
import '../../../../child_device/domain/usecases/watch_child_devices.dart';
import '../../../domain/entities/versioned_policy.dart';
import '../../../domain/usecases/get_device_policy.dart';

part 'policy_overview_event.dart';
part 'policy_overview_state.dart';

/// Politica do aparelho em foco para a visao geral das regras.
///
/// Acompanha a versao da politica pela lista de aparelhos: quando o servidor passa a ter uma
/// versao mais nova (comando do painel, outra sessao), recarrega em segundo plano.
class PolicyOverviewBloc extends Bloc<PolicyOverviewEvent, PolicyOverviewState> {
  PolicyOverviewBloc({
    required this._getDevicePolicy,
    required this._watchDevices,
    required this._refreshDevices,
  }) : super(const PolicyOverviewLoading()) {
    on<PolicyOverviewStarted>(_onStarted, transformer: restartable());
    on<PolicyOverviewRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<_PolicyOverviewServerVersionChanged>(_onServerVersionChanged, transformer: restartable());
  }

  final GetDevicePolicy _getDevicePolicy;
  final WatchChildDevices _watchDevices;
  final RefreshChildDevices _refreshDevices;

  Future<void> _onStarted(PolicyOverviewStarted event, Emitter<PolicyOverviewState> emit) async {
    emit(const PolicyOverviewLoading());
    emit(await _load(event.deviceId));
    await emit.onEach<int>(
      _watchDevices
          .device(event.deviceId)
          .where((ChildDevice? device) => device != null)
          .map((ChildDevice? device) => device!.policyVersion)
          .distinct(),
      onData: (int version) => add(_PolicyOverviewServerVersionChanged(version)),
    );
  }

  Future<void> _onRefreshRequested(
    PolicyOverviewRefreshRequested event,
    Emitter<PolicyOverviewState> emit,
  ) async {
    try {
      await _refreshDevices();
      final PolicyOverviewState current = state;
      final String? deviceId = switch (current) {
        PolicyOverviewLoaded(:final String deviceId) => deviceId,
        PolicyOverviewError(:final String deviceId) => deviceId,
        PolicyOverviewLoading() => null,
      };
      if (deviceId != null) {
        final PolicyOverviewState next = await _load(deviceId);
        // Falha ao atualizar com a politica ja na tela: mantem o que esta la.
        if (next is PolicyOverviewLoaded || current is! PolicyOverviewLoaded) {
          emit(next);
        }
      }
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onServerVersionChanged(
    _PolicyOverviewServerVersionChanged event,
    Emitter<PolicyOverviewState> emit,
  ) async {
    final PolicyOverviewState current = state;
    if (current is! PolicyOverviewLoaded || event.version <= current.policy.version) {
      return;
    }
    final PolicyOverviewState next = await _load(current.deviceId);
    if (next is PolicyOverviewLoaded && next.policy.version >= current.policy.version) {
      emit(next);
    }
  }

  Future<PolicyOverviewState> _load(String deviceId) async {
    final Result<VersionedPolicy> result = await _getDevicePolicy(deviceId);
    return switch (result) {
      Ok<VersionedPolicy>(:final VersionedPolicy value) => PolicyOverviewLoaded(
        deviceId: deviceId,
        policy: value,
      ),
      Err<VersionedPolicy>(:final AppFailure failure) => PolicyOverviewError(
        deviceId: deviceId,
        failure: failure,
      ),
    };
  }
}
