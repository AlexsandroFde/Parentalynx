import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../child_device/domain/usecases/watch_child_devices.dart';
import '../device_policy/device_policy_module.dart';
import 'data/datasources/remote/app_inventory_remote_data_source.dart';
import 'data/repositories/api_app_inventory_repository.dart';
import 'domain/entities/apps_section.dart';
import 'domain/repositories/i_app_inventory_repository.dart';
import 'domain/usecases/get_app_icon.dart';
import 'domain/usecases/get_device_apps.dart';
import 'presentation/bloc/app_inventory/app_inventory_bloc.dart';
import 'presentation/bloc/app_management/app_management_bloc.dart';
import 'presentation/services/app_icon_images.dart';

/// Registra as dependencias de apps do modo responsavel: inventario, icones e regras por app.
void registerAppManagementModule(GetIt di) {
  di
    ..registerLazySingleton<AppInventoryRemoteDataSource>(
      () => AppInventoryRemoteDataSource(di<ApiClient>()),
    )
    ..registerLazySingleton<IAppInventoryRepository>(
      () => ApiAppInventoryRepository(di<AppInventoryRemoteDataSource>()),
    )
    ..registerFactory<GetDeviceApps>(() => GetDeviceApps(di<IAppInventoryRepository>()))
    ..registerFactory<GetAppIcon>(() => GetAppIcon(di<IAppInventoryRepository>()))
    // Servico de interface: entregue as telas pela arvore de widgets.
    ..registerLazySingleton<AppIconImages>(() => RemoteAppIconImages(di<GetAppIcon>()))
    // Uma instancia por tela de regras de apps aberta.
    ..registerFactory<AppManagementBloc>(
      () => AppManagementBloc(editor: createPolicySectionEditor(di, const AppsSection())),
    )
    ..registerFactory<AppInventoryBloc>(
      () => AppInventoryBloc(
        getDeviceApps: di<GetDeviceApps>(),
        watchDevices: di<WatchChildDevices>(),
      ),
    );
}
