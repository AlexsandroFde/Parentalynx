import 'package:get_it/get_it.dart';

import '../../core/network/server_endpoint.dart';
import '../../core/network/session_credentials.dart';
import '../../core/platform/native_api.g.dart';
import 'data/repositories/realtime_repository.dart';
import 'data/services/native_device_sync_service.dart';
import 'domain/repositories/i_realtime_repository.dart';
import 'domain/services/i_device_sync_service.dart';
import 'domain/usecases/manage_realtime_connection.dart';
import 'domain/usecases/trigger_device_sync.dart';
import 'domain/usecases/watch_realtime_updates.dart';
import 'presentation/bloc/device_sync_bloc.dart';

/// Registra as dependencias de sincronizacao: canal em tempo real do responsavel e pedido de
/// sincronizacao ao agente da crianca.
void registerDeviceSyncModule(GetIt di) {
  di
    ..registerLazySingleton<IRealtimeRepository>(
      () =>
          RealtimeRepository(endpoint: di<ServerEndpoint>(), credentials: di<SessionCredentials>()),
    )
    ..registerLazySingleton<IDeviceSyncService>(() => NativeDeviceSyncService(di<ChildAgentApi>()))
    ..registerFactory<WatchRealtimeUpdates>(() => WatchRealtimeUpdates(di<IRealtimeRepository>()))
    ..registerFactory<ManageRealtimeConnection>(
      () => ManageRealtimeConnection(di<IRealtimeRepository>()),
    )
    ..registerFactory<TriggerDeviceSync>(() => TriggerDeviceSync(di<IDeviceSyncService>()))
    // Uma instancia por painel aberto.
    ..registerFactory<DeviceSyncBloc>(
      () => DeviceSyncBloc(connection: di<ManageRealtimeConnection>()),
    );
}
