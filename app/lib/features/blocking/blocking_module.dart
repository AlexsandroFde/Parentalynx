import 'package:get_it/get_it.dart';

import '../../core/time/clock.dart';
import '../authentication/domain/usecases/run_elevated.dart';
import '../child_device/domain/repositories/i_child_device_repository.dart';
import '../device_policy/device_policy_module.dart';
import '../device_policy/domain/repositories/i_policy_command_repository.dart';
import 'domain/entities/protection_section.dart';
import 'domain/entities/web_section.dart';
import 'domain/usecases/lock_device_now.dart';
import 'domain/usecases/resume_rules.dart';
import 'domain/usecases/suspend_rules.dart';
import 'domain/usecases/unlock_device.dart';
import 'presentation/bloc/protection/protection_bloc.dart';
import 'presentation/bloc/web_filter/web_filter_bloc.dart';

/// Registra as dependencias de bloqueio do modo responsavel: pausa, suspensao de regras,
/// protecao e filtro de sites.
void registerBlockingModule(GetIt di) {
  // Casos de uso.
  di
    ..registerFactory<LockDeviceNow>(
      () => LockDeviceNow(
        commands: di<IPolicyCommandRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
        clock: di<Clock>(),
      ),
    )
    ..registerFactory<UnlockDevice>(
      () => UnlockDevice(
        commands: di<IPolicyCommandRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<SuspendRules>(
      () => SuspendRules(
        commands: di<IPolicyCommandRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<ResumeRules>(
      () => ResumeRules(
        commands: di<IPolicyCommandRepository>(),
        devices: di<IChildDeviceRepository>(),
        elevated: di<RunElevated>(),
      ),
    );

  // Apresentacao: uma instancia por tela aberta.
  di
    ..registerFactory<ProtectionBloc>(
      () => ProtectionBloc(editor: createPolicySectionEditor(di, const ProtectionSection())),
    )
    ..registerFactory<WebFilterBloc>(
      () => WebFilterBloc(editor: createPolicySectionEditor(di, const WebSection())),
    );
}
