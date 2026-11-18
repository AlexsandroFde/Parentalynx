import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/time/clock.dart';
import '../authentication/domain/usecases/run_elevated.dart';
import '../device_sync/domain/usecases/watch_realtime_updates.dart';
import 'data/datasources/remote/child_device_remote_data_source.dart';
import 'data/repositories/api_child_device_repository.dart';
import 'domain/repositories/i_child_device_repository.dart';
import 'domain/usecases/compute_offline_access_code.dart';
import 'domain/usecases/delete_child_device.dart';
import 'domain/usecases/delete_child_device_data.dart';
import 'domain/usecases/export_child_device_data.dart';
import 'domain/usecases/get_offline_access_secret.dart';
import 'domain/usecases/refresh_child_devices.dart';
import 'domain/usecases/rename_child_device.dart';
import 'domain/usecases/revoke_device_link.dart';
import 'domain/usecases/watch_child_devices.dart';
import 'presentation/bloc/child_device/child_device_bloc.dart';
import 'presentation/bloc/devices/devices_bloc.dart';
import 'presentation/bloc/offline_code/offline_code_bloc.dart';

/// Registra as dependencias dos aparelhos monitorados (visao do responsavel).
void registerChildDeviceModule(GetIt di) {
  di
    ..registerLazySingleton<ChildDeviceRemoteDataSource>(
      () => ChildDeviceRemoteDataSource(di<ApiClient>()),
    )
    // Fonte unica de verdade da lista de aparelhos: uma instancia para o app inteiro.
    ..registerLazySingleton<IChildDeviceRepository>(
      () => ApiChildDeviceRepository(di<ChildDeviceRemoteDataSource>()),
    )
    ..registerFactory<WatchChildDevices>(() => WatchChildDevices(di<IChildDeviceRepository>()))
    ..registerFactory<RefreshChildDevices>(() => RefreshChildDevices(di<IChildDeviceRepository>()))
    ..registerFactory<RenameChildDevice>(
      () =>
          RenameChildDevice(repository: di<IChildDeviceRepository>(), elevated: di<RunElevated>()),
    )
    ..registerFactory<RevokeDeviceLink>(
      () => RevokeDeviceLink(repository: di<IChildDeviceRepository>(), elevated: di<RunElevated>()),
    )
    ..registerFactory<DeleteChildDevice>(
      () =>
          DeleteChildDevice(repository: di<IChildDeviceRepository>(), elevated: di<RunElevated>()),
    )
    ..registerFactory<DeleteChildDeviceData>(
      () => DeleteChildDeviceData(
        repository: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<ExportChildDeviceData>(
      () => ExportChildDeviceData(
        repository: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<GetOfflineAccessSecret>(
      () => GetOfflineAccessSecret(
        repository: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<ComputeOfflineAccessCode>(() => const ComputeOfflineAccessCode())
    // Um por painel aberto: a lista e a selecao valem para todas as abas.
    ..registerFactory<DevicesBloc>(
      () => DevicesBloc(
        watchDevices: di<WatchChildDevices>(),
        refreshDevices: di<RefreshChildDevices>(),
        watchRealtimeUpdates: di<WatchRealtimeUpdates>(),
      ),
    )
    // Um por tela de detalhe aberta.
    ..registerFactory<ChildDeviceBloc>(
      () => ChildDeviceBloc(
        watchDevices: di<WatchChildDevices>(),
        refreshDevices: di<RefreshChildDevices>(),
        rename: di<RenameChildDevice>(),
        revoke: di<RevokeDeviceLink>(),
        delete: di<DeleteChildDevice>(),
        deleteData: di<DeleteChildDeviceData>(),
        export: di<ExportChildDeviceData>(),
        offlineSecret: di<GetOfflineAccessSecret>(),
      ),
    )
    // Um por folha do codigo offline aberta; recebe o segredo do aparelho.
    ..registerFactoryParam<OfflineCodeBloc, String, void>(
      (String secret, void _) => OfflineCodeBloc(
        secret: secret,
        compute: di<ComputeOfflineAccessCode>(),
        clock: di<Clock>(),
      ),
    );
}
