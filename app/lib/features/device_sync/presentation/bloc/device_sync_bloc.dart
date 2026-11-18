import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../domain/usecases/manage_realtime_connection.dart';

part 'device_sync_event.dart';
part 'device_sync_state.dart';

/// Canal de atualizacoes em tempo real do painel do responsavel.
///
/// Vive enquanto o painel estiver aberto: abre o canal ao comecar e fecha ao ser descartado.
/// Os outros BLoCs nao dependem deste: eles observam os avisos pelo caso de uso
/// `WatchRealtimeUpdates`.
class DeviceSyncBloc extends Bloc<DeviceSyncEvent, DeviceSyncState> {
  DeviceSyncBloc({required this._connection}) : super(const DeviceSyncIdle()) {
    on<DeviceSyncStarted>(_onStarted, transformer: restartable());
  }

  final ManageRealtimeConnection _connection;

  Future<void> _onStarted(DeviceSyncStarted event, Emitter<DeviceSyncState> emit) async {
    emit(const DeviceSyncConnecting());
    _connection.open();
    bool connectedOnce = false;
    await emit.forEach<bool>(
      _connection.watchConnection(),
      onData: (bool connected) {
        if (connected) {
          connectedOnce = true;
          return const DeviceSyncOnline();
        }
        // Antes da primeira conexao o canal ainda esta abrindo.
        return connectedOnce ? const DeviceSyncOffline() : const DeviceSyncConnecting();
      },
    );
  }

  @override
  Future<void> close() async {
    await _connection.close();
    return super.close();
  }
}
