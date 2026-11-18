import 'package:get_it/get_it.dart';

import '../../core/navigation/launch_action.dart';
import '../../core/platform/native_api.g.dart';
import '../app_management/domain/usecases/get_always_allowed_apps.dart';
import '../app_management/domain/usecases/get_today_app_usage.dart';
import '../app_management/domain/usecases/launch_allowed_app.dart';
import '../blocking/domain/usecases/clear_local_override.dart';
import '../blocking/domain/usecases/grant_local_override.dart';
import '../device_linking/domain/usecases/finish_link_onboarding.dart';
import '../device_linking/domain/usecases/get_device_identity.dart';
import '../device_linking/domain/usecases/report_agent_inactive.dart';
import '../device_linking/domain/usecases/unlink_this_device.dart';
import '../device_linking/domain/usecases/watch_link_state.dart';
import '../device_policy/domain/usecases/get_active_policy.dart';
import '../device_sync/domain/usecases/trigger_device_sync.dart';
import '../managed_browser/domain/usecases/open_managed_browser.dart';
import '../screen_time/domain/usecases/get_own_time_requests.dart';
import 'data/services/native_boot_recovery_service.dart';
import 'data/services/native_device_agent_service.dart';
import 'data/services/native_device_management_service.dart';
import 'data/services/native_guardian_authorization_service.dart';
import 'data/services/native_platform_permission_service.dart';
import 'domain/services/i_boot_recovery_service.dart';
import 'domain/services/i_device_agent_service.dart';
import 'domain/services/i_device_management_service.dart';
import 'domain/services/i_guardian_authorization_service.dart';
import 'domain/services/i_platform_permission_service.dart';
import 'domain/usecases/check_permissions.dart';
import 'domain/usecases/disable_device_admin.dart';
import 'domain/usecases/enable_device_admin.dart';
import 'domain/usecases/ensure_agent_running.dart';
import 'domain/usecases/get_agent_status.dart';
import 'domain/usecases/load_child_home_summary.dart';
import 'domain/usecases/open_app_details_settings.dart';
import 'domain/usecases/open_permission_settings.dart';
import 'domain/usecases/release_device_ownership.dart';
import 'domain/usecases/verify_guardian_password.dart';
import 'domain/usecases/verify_offline_access_code.dart';
import 'domain/usecases/watch_child_launch_action.dart';
import 'presentation/bloc/child_device_status/child_device_status_bloc.dart';
import 'presentation/bloc/child_home/child_home_bloc.dart';
import 'presentation/bloc/child_shell/child_shell_bloc.dart';
import 'presentation/bloc/guardian_area/guardian_area_bloc.dart';
import 'presentation/bloc/permissions/permissions_bloc.dart';
import 'presentation/services/foreground_tracker.dart';

/// Registra o modo crianca: agente nativo (retrato, recuperacao do servico), permissoes do
/// Android, autenticacao do responsavel no aparelho e os BLoCs das telas.
///
/// Depende dos modulos do lado da crianca de vinculacao (`registerDeviceLinkingChildModule`),
/// apps (`registerAppManagementChildModule`), tempo de tela
/// (`registerScreenTimeChildModule`), bloqueio (`registerBlockingChildModule`), do navegador
/// gerenciado (`registerManagedBrowserModule`) e dos modulos de base (sincronizacao e
/// politica).
void registerChildModeModule(GetIt di) {
  // Dados.
  di
    ..registerLazySingleton<IDeviceAgentService>(
      () => NativeDeviceAgentService(di<ChildAgentApi>()),
    )
    ..registerLazySingleton<IBootRecoveryService>(
      () => NativeBootRecoveryService(di<ChildAgentApi>()),
    )
    ..registerLazySingleton<IPlatformPermissionService>(
      () => NativePlatformPermissionService(di<DeviceApi>()),
    )
    ..registerLazySingleton<IGuardianAuthorizationService>(
      () => NativeGuardianAuthorizationService(di<ChildAgentApi>()),
    )
    ..registerLazySingleton<IDeviceManagementService>(
      () => NativeDeviceManagementService(di<DeviceApi>()),
    );

  // Casos de uso.
  di
    ..registerFactory<GetAgentStatus>(() => GetAgentStatus(di<IDeviceAgentService>()))
    ..registerFactory<EnsureAgentRunning>(() => EnsureAgentRunning(di<IBootRecoveryService>()))
    ..registerFactory<LoadChildHomeSummary>(
      () => LoadChildHomeSummary(
        getActivePolicy: di<GetActivePolicy>(),
        getTodayAppUsage: di<GetTodayAppUsage>(),
        getAlwaysAllowedApps: di<GetAlwaysAllowedApps>(),
        getOwnTimeRequests: di<GetOwnTimeRequests>(),
      ),
    )
    ..registerFactory<CheckPermissions>(
      () => CheckPermissions(
        permissions: di<IPlatformPermissionService>(),
        getDeviceIdentity: di<GetDeviceIdentity>(),
      ),
    )
    ..registerFactory<OpenPermissionSettings>(
      () => OpenPermissionSettings(
        permissions: di<IPlatformPermissionService>(),
        management: di<IDeviceManagementService>(),
      ),
    )
    ..registerFactory<OpenAppDetailsSettings>(
      () => OpenAppDetailsSettings(di<IPlatformPermissionService>()),
    )
    ..registerFactory<VerifyGuardianPassword>(
      () => VerifyGuardianPassword(di<IGuardianAuthorizationService>()),
    )
    ..registerFactory<VerifyOfflineAccessCode>(
      () => VerifyOfflineAccessCode(di<IGuardianAuthorizationService>()),
    )
    ..registerFactory<EnableDeviceAdmin>(() => EnableDeviceAdmin(di<IDeviceManagementService>()))
    ..registerFactory<DisableDeviceAdmin>(() => DisableDeviceAdmin(di<IDeviceManagementService>()))
    ..registerFactory<ReleaseDeviceOwnership>(
      () => ReleaseDeviceOwnership(di<IDeviceManagementService>()),
    )
    ..registerFactory<WatchChildLaunchAction>(
      () => WatchChildLaunchAction(di<LaunchActionSource>()),
    );

  // Apresentacao. Um rastreador de primeiro plano por app; um BLoC por casca ou por tela.
  di
    ..registerLazySingleton<ForegroundTracker>(ForegroundTracker.new)
    ..registerFactory<ChildShellBloc>(
      () => ChildShellBloc(
        launchAction: di<WatchChildLaunchAction>(),
        watchLinkState: di<WatchLinkState>(),
      ),
    )
    ..registerFactory<ChildDeviceStatusBloc>(
      () => ChildDeviceStatusBloc(
        getAgentStatus: di<GetAgentStatus>(),
        ensureAgentRunning: di<EnsureAgentRunning>(),
        watchLinkState: di<WatchLinkState>(),
        reportAgentInactive: di<ReportAgentInactive>(),
        foreground: di<ForegroundTracker>(),
      ),
    )
    ..registerFactory<ChildHomeBloc>(
      () => ChildHomeBloc(
        loadSummary: di<LoadChildHomeSummary>(),
        triggerDeviceSync: di<TriggerDeviceSync>(),
        openManagedBrowser: di<OpenManagedBrowser>(),
        launchAllowedApp: di<LaunchAllowedApp>(),
        foreground: di<ForegroundTracker>(),
      ),
    )
    ..registerFactory<PermissionsBloc>(
      () => PermissionsBloc(
        checkPermissions: di<CheckPermissions>(),
        openPermissionSettings: di<OpenPermissionSettings>(),
        openAppDetailsSettings: di<OpenAppDetailsSettings>(),
        finishLinkOnboarding: di<FinishLinkOnboarding>(),
      ),
    )
    ..registerFactory<GuardianAreaBloc>(
      () => GuardianAreaBloc(
        verifyGuardianPassword: di<VerifyGuardianPassword>(),
        verifyOfflineAccessCode: di<VerifyOfflineAccessCode>(),
        grantLocalOverride: di<GrantLocalOverride>(),
        clearLocalOverride: di<ClearLocalOverride>(),
        enableDeviceAdmin: di<EnableDeviceAdmin>(),
        disableDeviceAdmin: di<DisableDeviceAdmin>(),
        releaseDeviceOwnership: di<ReleaseDeviceOwnership>(),
        unlinkThisDevice: di<UnlinkThisDevice>(),
      ),
    );
}
