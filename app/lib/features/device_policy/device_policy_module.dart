import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/platform/native_api.g.dart';
import '../authentication/domain/usecases/run_elevated.dart';
import '../child_device/domain/repositories/i_child_device_repository.dart';
import '../child_device/domain/usecases/refresh_child_devices.dart';
import '../child_device/domain/usecases/watch_child_devices.dart';
import 'data/datasources/remote/device_policy_remote_data_source.dart';
import 'data/repositories/api_device_policy_repository.dart';
import 'data/services/native_device_policy_service.dart';
import 'domain/entities/policy_section.dart';
import 'domain/repositories/i_device_policy_repository.dart';
import 'domain/repositories/i_policy_command_repository.dart';
import 'domain/services/i_device_policy_service.dart';
import 'domain/usecases/get_active_policy.dart';
import 'domain/usecases/get_device_policy.dart';
import 'domain/usecases/save_policy_section.dart';
import 'presentation/bloc/policy_overview/policy_overview_bloc.dart';
import 'presentation/editing/policy_section_editor.dart';

/// Registra as dependencias da politica dos aparelhos (documento versionado e comandos).
void registerDevicePolicyModule(GetIt di) {
  di
    ..registerLazySingleton<DevicePolicyRemoteDataSource>(
      () => DevicePolicyRemoteDataSource(di<ApiClient>()),
    )
    // Uma instancia atende as duas interfaces (documento e comandos).
    ..registerLazySingleton<ApiDevicePolicyRepository>(
      () => ApiDevicePolicyRepository(di<DevicePolicyRemoteDataSource>()),
    )
    ..registerLazySingleton<IDevicePolicyRepository>(() => di<ApiDevicePolicyRepository>())
    ..registerLazySingleton<IPolicyCommandRepository>(() => di<ApiDevicePolicyRepository>())
    ..registerLazySingleton<IDevicePolicyService>(
      () => NativeDevicePolicyService(di<ChildAgentApi>()),
    )
    ..registerFactory<GetDevicePolicy>(() => GetDevicePolicy(di<IDevicePolicyRepository>()))
    ..registerFactory<SavePolicySection>(
      () => SavePolicySection(
        policies: di<IDevicePolicyRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<GetActivePolicy>(() => GetActivePolicy(di<IDevicePolicyService>()))
    // Uma instancia por visao geral aberta (aba Regras).
    ..registerFactory<PolicyOverviewBloc>(
      () => PolicyOverviewBloc(
        getDevicePolicy: di<GetDevicePolicy>(),
        watchDevices: di<WatchChildDevices>(),
        refreshDevices: di<RefreshChildDevices>(),
      ),
    );
}

/// Monta o editor de uma secao da politica, para os modulos das funcionalidades de regras.
PolicySectionEditor<T> createPolicySectionEditor<T>(GetIt di, PolicySection<T> section) {
  return PolicySectionEditor<T>(
    section: section,
    getDevicePolicy: di<GetDevicePolicy>(),
    savePolicySection: di<SavePolicySection>(),
    watchDevices: di<WatchChildDevices>(),
  );
}
