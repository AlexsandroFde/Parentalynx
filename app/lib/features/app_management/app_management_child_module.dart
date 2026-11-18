import 'package:get_it/get_it.dart';

import '../../core/platform/native_api.g.dart';
import 'data/services/native_application_monitor.dart';
import 'domain/services/i_application_monitor.dart';
import 'domain/usecases/get_always_allowed_apps.dart';
import 'domain/usecases/get_installed_app_icon.dart';
import 'domain/usecases/get_today_app_usage.dart';
import 'domain/usecases/launch_allowed_app.dart';
import 'presentation/services/installed_app_icons.dart';

/// Registra as dependencias de apps do modo crianca: uso de hoje, apps sempre liberados,
/// icones e abertura de apps, pelo agente nativo.
void registerAppManagementChildModule(GetIt di) {
  di
    ..registerLazySingleton<IApplicationMonitor>(
      () => NativeApplicationMonitor(di<ChildAgentApi>()),
    )
    ..registerFactory<GetTodayAppUsage>(() => GetTodayAppUsage(di<IApplicationMonitor>()))
    ..registerFactory<GetAlwaysAllowedApps>(() => GetAlwaysAllowedApps(di<IApplicationMonitor>()))
    ..registerFactory<GetInstalledAppIcon>(() => GetInstalledAppIcon(di<IApplicationMonitor>()))
    ..registerFactory<LaunchAllowedApp>(() => LaunchAllowedApp(di<IApplicationMonitor>()))
    // Servico de interface: entregue as telas do modo crianca pela arvore de widgets.
    ..registerLazySingleton<InstalledAppIcons>(
      () => SessionInstalledAppIcons(di<GetInstalledAppIcon>()),
    );
}
