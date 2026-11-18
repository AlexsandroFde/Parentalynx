import 'package:get_it/get_it.dart';

import '../../core/navigation/launch_action.dart';
import '../../core/time/clock.dart';
import '../app_management/domain/usecases/get_device_apps.dart';
import '../blocking/domain/usecases/lock_device_now.dart';
import '../blocking/domain/usecases/resume_rules.dart';
import '../blocking/domain/usecases/suspend_rules.dart';
import '../blocking/domain/usecases/unlock_device.dart';
import '../child_device/domain/usecases/watch_child_devices.dart';
import '../device_policy/domain/usecases/get_device_policy.dart';
import '../notifications/domain/usecases/get_recent_alerts.dart';
import '../notifications/domain/usecases/watch_incoming_alerts.dart';
import '../screen_time/domain/usecases/grant_additional_time.dart';
import 'domain/usecases/watch_launch_action.dart';
import 'presentation/bloc/dashboard/guardian_dashboard_bloc.dart';
import 'presentation/bloc/shell/guardian_shell_bloc.dart';

/// Registra as dependencias do painel do responsavel: a casca das abas e a tela Inicio.
///
/// Depende dos casos de uso registrados pelos modulos de aparelhos, politica, notificacoes,
/// apps, bloqueio e tempo de tela.
void registerGuardianModule(GetIt di) {
  // Casos de uso.
  di.registerFactory<WatchLaunchAction>(() => WatchLaunchAction(di<LaunchActionSource>()));

  // Apresentacao: uma instancia por painel aberto.
  di
    ..registerFactory<GuardianShellBloc>(
      () => GuardianShellBloc(launchAction: di<WatchLaunchAction>()),
    )
    ..registerFactory<GuardianDashboardBloc>(
      () => GuardianDashboardBloc(
        watchDevices: di<WatchChildDevices>(),
        getDevicePolicy: di<GetDevicePolicy>(),
        getDeviceApps: di<GetDeviceApps>(),
        getRecentAlerts: di<GetRecentAlerts>(),
        incomingAlerts: di<WatchIncomingAlerts>(),
        grantAdditionalTime: di<GrantAdditionalTime>(),
        lockDeviceNow: di<LockDeviceNow>(),
        unlockDevice: di<UnlockDevice>(),
        suspendRules: di<SuspendRules>(),
        resumeRules: di<ResumeRules>(),
        clock: di<Clock>(),
      ),
    );
}
