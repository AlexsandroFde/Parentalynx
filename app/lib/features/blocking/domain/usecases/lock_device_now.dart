import 'dart:async';

import '../../../../core/result/result.dart';
import '../../../../core/time/clock.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../../../device_policy/domain/entities/versioned_policy.dart';
import '../../../device_policy/domain/repositories/i_policy_command_repository.dart';

/// Pausa o aparelho agora ("Pausar agora"). Operacao administrativa.
///
/// Com [duration], a pausa termina sozinha; sem, vale ate o responsavel retomar. Quem aplica o
/// bloqueio e o agente nativo do aparelho, que recebe o comando na politica.
class LockDeviceNow {
  const LockDeviceNow({
    required this._commands,
    required this._devices,
    required this._elevated,
    required this._clock,
  });

  final IPolicyCommandRepository _commands;
  final IChildDeviceRepository _devices;
  final RunElevated _elevated;
  final Clock _clock;

  Future<Result<VersionedPolicy>> call(String deviceId, {Duration? duration}) async {
    final int? until = duration == null ? null : _clock.now().add(duration).millisecondsSinceEpoch;
    final Result<VersionedPolicy> result = await _elevated<VersionedPolicy>(
      () => _commands.lock(deviceId, until: until),
    );
    if (result.isOk) {
      unawaited(_devices.refresh());
    }
    return result;
  }
}
