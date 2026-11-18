import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/domain/entities/versioned_policy.dart';
import '../../../device_policy/domain/repositories/i_policy_command_repository.dart';

/// Suspende regras do aparelho por alguns minutos (limite, horarios, apps bloqueados).
/// Operacao administrativa.
class SuspendRules {
  const SuspendRules({required this._commands, required this._devices, required this._elevated});

  final IPolicyCommandRepository _commands;
  final IChildDeviceRepository _devices;
  final RunElevated _elevated;

  Future<Result<VersionedPolicy>> call(
    String deviceId, {
    required int minutes,
    required List<SuspensionScope> scopes,
  }) async {
    if (scopes.isEmpty) {
      return const Err<VersionedPolicy>(
        ValidationFailure('Escolha pelo menos uma regra para suspender.'),
      );
    }
    if (minutes < 1) {
      return const Err<VersionedPolicy>(ValidationFailure('Escolha por quanto tempo suspender.'));
    }
    final Result<VersionedPolicy> result = await _elevated<VersionedPolicy>(
      () => _commands.suspend(deviceId, minutes: minutes, scopes: scopes),
    );
    if (result.isOk) {
      unawaited(_devices.refresh());
    }
    return result;
  }
}
