import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../authentication/domain/usecases/run_elevated.dart';
import '../child_device/domain/repositories/i_child_device_repository.dart';
import '../child_device/domain/usecases/refresh_child_devices.dart';
import '../child_device/domain/usecases/watch_child_devices.dart';
import '../device_policy/device_policy_module.dart';
import '../device_policy/domain/repositories/i_policy_command_repository.dart';
import '../device_sync/domain/usecases/watch_realtime_updates.dart';
import 'data/datasources/remote/time_requests_remote_data_source.dart';
import 'data/repositories/api_time_requests_repository.dart';
import 'domain/entities/daily_limit_section.dart';
import 'domain/repositories/i_time_requests_repository.dart';
import 'domain/usecases/approve_time_request.dart';
import 'domain/usecases/deny_time_request.dart';
import 'domain/usecases/grant_additional_time.dart';
import 'domain/usecases/list_time_requests.dart';
import 'presentation/bloc/screen_time/screen_time_bloc.dart';
import 'presentation/bloc/time_requests/time_requests_bloc.dart';

/// Registra as dependencias de tempo de tela do modo responsavel: limite diario, tempo extra
/// e pedidos de tempo.
void registerScreenTimeModule(GetIt di) {
  // Dados.
  di
    ..registerLazySingleton<TimeRequestsRemoteDataSource>(
      () => TimeRequestsRemoteDataSource(di<ApiClient>()),
    )
    ..registerLazySingleton<ITimeRequestsRepository>(
      () => ApiTimeRequestsRepository(di<TimeRequestsRemoteDataSource>()),
    );

  // Casos de uso.
  di
    ..registerFactory<GrantAdditionalTime>(
      () => GrantAdditionalTime(
        commands: di<IPolicyCommandRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<ListTimeRequests>(() => ListTimeRequests(di<ITimeRequestsRepository>()))
    ..registerFactory<ApproveTimeRequest>(
      () => ApproveTimeRequest(
        repository: di<ITimeRequestsRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<DenyTimeRequest>(
      () => DenyTimeRequest(
        repository: di<ITimeRequestsRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    );

  // Apresentacao: uma instancia por tela aberta.
  di
    ..registerFactory<ScreenTimeBloc>(
      () => ScreenTimeBloc(editor: createPolicySectionEditor(di, const DailyLimitSection())),
    )
    ..registerFactory<TimeRequestsBloc>(
      () => TimeRequestsBloc(
        listTimeRequests: di<ListTimeRequests>(),
        approveTimeRequest: di<ApproveTimeRequest>(),
        denyTimeRequest: di<DenyTimeRequest>(),
        watchDevices: di<WatchChildDevices>(),
        refreshDevices: di<RefreshChildDevices>(),
        watchRealtimeUpdates: di<WatchRealtimeUpdates>(),
      ),
    );
}
