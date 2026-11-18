import 'dart:async';

import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../../../device_policy/domain/entities/versioned_policy.dart';
import '../../../device_policy/domain/repositories/i_policy_command_repository.dart';

/// Encerra a pausa do aparelho ("Retomar"). Operacao administrativa.
class UnlockDevice {
  const UnlockDevice({required this._commands, required this._devices, required this._elevated});

  final IPolicyCommandRepository _commands;
  final IChildDeviceRepository _devices;
  final RunElevated _elevated;

  Future<Result<VersionedPolicy>> call(String deviceId) async {
    final Result<VersionedPolicy> result = await _elevated<VersionedPolicy>(
      () => _commands.unlock(deviceId),
    );
    if (result.isOk) {
      unawaited(_devices.refresh());
    }
    return result;
  }
}
