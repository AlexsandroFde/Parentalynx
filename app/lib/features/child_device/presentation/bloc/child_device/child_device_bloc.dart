import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/child_device.dart';
import '../../../domain/usecases/delete_child_device.dart';
import '../../../domain/usecases/delete_child_device_data.dart';
import '../../../domain/usecases/export_child_device_data.dart';
import '../../../domain/usecases/get_offline_access_secret.dart';
import '../../../domain/usecases/refresh_child_devices.dart';
import '../../../domain/usecases/rename_child_device.dart';
import '../../../domain/usecases/revoke_device_link.dart';
import '../../../domain/usecases/watch_child_devices.dart';

part 'child_device_event.dart';
part 'child_device_state.dart';

/// Estado do aparelho monitorado na tela de detalhe: identificacao, protecao e permissoes, e
/// as acoes administrativas (renomear, desvincular, apagar, exportar, codigo offline).
///
/// O aparelho vem da lista da conta (fonte unica de verdade): quando uma acao muda o aparelho,
/// a lista avisa e a tela acompanha.
class ChildDeviceBloc extends Bloc<ChildDeviceEvent, ChildDeviceState> {
  ChildDeviceBloc({
    required this._watchDevices,
    required this._refreshDevices,
    required this._rename,
    required this._revoke,
    required this._delete,
    required this._deleteData,
    required this._export,
    required this._offlineSecret,
  }) : super(const ChildDeviceLoading()) {
    on<ChildDeviceStarted>(_onStarted, transformer: restartable());
    on<ChildDeviceRenameRequested>(_onRename, transformer: droppable());
    on<ChildDeviceRevokeRequested>(_onRevoke, transformer: droppable());
    on<ChildDeviceDataDeleteRequested>(_onDeleteData, transformer: droppable());
    on<ChildDeviceDeleteRequested>(_onDelete, transformer: droppable());
    on<ChildDeviceExportRequested>(_onExport, transformer: droppable());
    on<ChildDeviceOfflineCodeRequested>(_onOfflineCode, transformer: droppable());
  }

  final WatchChildDevices _watchDevices;
  final RefreshChildDevices _refreshDevices;
  final RenameChildDevice _rename;
  final RevokeDeviceLink _revoke;
  final DeleteChildDevice _delete;
  final DeleteChildDeviceData _deleteData;
  final ExportChildDeviceData _export;
  final GetOfflineAccessSecret _offlineSecret;

  Future<void> _onStarted(ChildDeviceStarted event, Emitter<ChildDeviceState> emit) async {
    await Future.wait(<Future<void>>[
      emit.forEach<ChildDevice?>(
        _watchDevices.device(event.deviceId),
        onData: (ChildDevice? device) {
          final ChildDeviceState current = state;
          if (current is ChildDeviceRemoved) {
            return current;
          }
          if (device == null) {
            return const ChildDeviceNotFound();
          }
          return current is ChildDeviceLoaded
              ? current.copyWith(device: device, outcome: current.outcome)
              : ChildDeviceLoaded(device: device);
        },
      ),
      // Aberto direto (sem a lista do painel carregada): busca a lista da conta. Sem a lista,
      // a tela mostra que o aparelho nao foi encontrado.
      if (_watchDevices.cached == null)
        () async {
          final Result<List<ChildDevice>> result = await _refreshDevices();
          if (result is Err<List<ChildDevice>> && !emit.isDone && state is ChildDeviceLoading) {
            emit(const ChildDeviceNotFound());
          }
        }(),
    ]);
  }

  Future<void> _onRename(ChildDeviceRenameRequested event, Emitter<ChildDeviceState> emit) {
    return _run(
      emit,
      (ChildDevice device) => _rename(device.id, childName: event.childName),
      success: 'Nome alterado.',
    );
  }

  Future<void> _onRevoke(ChildDeviceRevokeRequested event, Emitter<ChildDeviceState> emit) {
    return _run(emit, (ChildDevice device) => _revoke(device.id), success: 'Vínculo revogado.');
  }

  Future<void> _onDeleteData(ChildDeviceDataDeleteRequested event, Emitter<ChildDeviceState> emit) {
    return _run(
      emit,
      (ChildDevice device) => _deleteData(device.id),
      success: 'Histórico apagado.',
    );
  }

  Future<void> _onDelete(ChildDeviceDeleteRequested event, Emitter<ChildDeviceState> emit) async {
    final ChildDeviceState current = state;
    if (current is! ChildDeviceLoaded || current.busy) {
      return;
    }
    emit(current.copyWith(action: const ActionRunning()));
    final Result<void> result = await _delete(current.device.id);
    switch (result) {
      case Ok<void>():
        emit(const ChildDeviceRemoved());
      case Err<void>(:final AppFailure failure):
        _emitFailure(emit, failure);
    }
  }

  Future<void> _onExport(ChildDeviceExportRequested event, Emitter<ChildDeviceState> emit) {
    return _run<String>(
      emit,
      (ChildDevice device) => _export(device.id),
      outcome: ChildDeviceExportReady.new,
    );
  }

  Future<void> _onOfflineCode(
    ChildDeviceOfflineCodeRequested event,
    Emitter<ChildDeviceState> emit,
  ) {
    return _run<String>(
      emit,
      (ChildDevice device) => _offlineSecret(device.id),
      outcome: ChildDeviceOfflineSecretReady.new,
    );
  }

  /// Roda uma acao administrativa sobre o aparelho carregado. Desistir do pedido de senha
  /// volta ao estado anterior sem aviso.
  Future<void> _run<T>(
    Emitter<ChildDeviceState> emit,
    Future<Result<T>> Function(ChildDevice device) action, {
    String? success,
    ChildDeviceOutcome Function(T value)? outcome,
  }) async {
    final ChildDeviceState current = state;
    if (current is! ChildDeviceLoaded || current.busy) {
      return;
    }
    emit(current.copyWith(action: const ActionRunning()));
    final Result<T> result = await action(current.device);
    switch (result) {
      case Ok<T>(:final T value):
        final ChildDeviceState latest = state;
        if (latest is ChildDeviceLoaded) {
          emit(
            latest.copyWith(
              action: ActionSucceeded(message: success),
              outcome: outcome?.call(value),
            ),
          );
        }
      case Err<T>(:final AppFailure failure):
        _emitFailure(emit, failure);
    }
  }

  void _emitFailure(Emitter<ChildDeviceState> emit, AppFailure failure) {
    final ChildDeviceState latest = state;
    if (latest is ChildDeviceLoaded) {
      emit(latest.copyWith(action: actionStatusForFailure(failure)));
    }
  }
}
