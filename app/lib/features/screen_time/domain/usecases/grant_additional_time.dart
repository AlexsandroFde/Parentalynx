import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../../../device_policy/domain/entities/versioned_policy.dart';
import '../../../device_policy/domain/repositories/i_policy_command_repository.dart';

/// Concede minutos extras para o dia corrente de um aparelho. Operacao administrativa.
///
/// O tempo extra e gravado como comando na politica: vale ate o fim do dia da cota, sobrevive
/// a perda de conexao do aparelho e reenviar a mesma concessao nao soma duas vezes.
class GrantAdditionalTime {
  const GrantAdditionalTime({
    required this._commands,
    required this._devices,
    required this._elevated,
  });

  /// Maior tempo extra aceito de uma vez: 12 horas.
  static const int maxMinutes = 720;

  final IPolicyCommandRepository _commands;
  final IChildDeviceRepository _devices;
  final RunElevated _elevated;

  Future<Result<VersionedPolicy>> call(String deviceId, {required int minutes}) async {
    if (minutes < 1 || minutes > maxMinutes) {
      return const Err<VersionedPolicy>(
        ValidationFailure('Escolha entre 1 minuto e 12 horas de tempo extra.'),
      );
    }
    final Result<VersionedPolicy> result = await _elevated<VersionedPolicy>(
      () => _commands.grantExtraTime(deviceId, minutes: minutes),
    );
    if (result.isOk) {
      // A versao nova fica pendente no painel ate o aparelho confirmar.
      unawaited(_devices.refresh());
    }
    return result;
  }
}
