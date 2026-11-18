import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../entities/policy.dart';
import '../entities/policy_save_outcome.dart';
import '../entities/policy_section.dart';
import '../entities/versioned_policy.dart';
import '../repositories/i_device_policy_repository.dart';

/// Salva uma secao editada da politica de um aparelho.
///
/// Concorrencia otimista por secao: a politica e gravada sobre a versao em que a edicao
/// comecou ([base]). Se outra sessao (ou um comando do painel) gerou uma versao nova nesse
/// meio tempo, o servidor recusa com `version_conflict` e:
/// - se a *mesma secao* mudou no servidor, nada e gravado e o resultado e [PolicyConflict]
///   com a versao atual, para a pessoa revisar;
/// - se mudaram outras secoes ou so os comandos, a secao editada e aplicada sobre a versao
///   atual e gravada de novo, sem perder o que a outra sessao fez.
///
/// Salvar e uma operacao administrativa (pede a senha se o servidor exigir). Depois de salvar,
/// a lista de aparelhos e atualizada para o painel mostrar a versao nova como pendente ate o
/// aparelho confirmar.
class SavePolicySection {
  const SavePolicySection({
    required this._policies,
    required this._devices,
    required this._elevated,
  });

  final IDevicePolicyRepository _policies;
  final IChildDeviceRepository _devices;
  final RunElevated _elevated;

  Future<Result<PolicySaveOutcome>> call<T>({
    required String deviceId,
    required VersionedPolicy base,
    required T value,
    required PolicySection<T> section,
  }) async {
    final Result<VersionedPolicy> first = await _replace(
      deviceId,
      baseVersion: base.version,
      policy: section.write(base.policy, value).editable,
    );
    switch (first) {
      case Ok<VersionedPolicy>(value: final VersionedPolicy saved):
        return _saved(saved);
      case Err<VersionedPolicy>(failure: ApiFailure(isVersionConflict: true)):
        break;
      case Err<VersionedPolicy>(:final AppFailure failure):
        return Err<PolicySaveOutcome>(failure);
    }

    final Result<VersionedPolicy> latestResult = await _policies.fetch(deviceId);
    final VersionedPolicy latest;
    switch (latestResult) {
      case Ok<VersionedPolicy>(:final VersionedPolicy value):
        latest = value;
      case Err<VersionedPolicy>(:final AppFailure failure):
        return Err<PolicySaveOutcome>(failure);
    }
    if (section.read(latest.policy) != section.read(base.policy)) {
      return Ok<PolicySaveOutcome>(PolicyConflict(latest));
    }
    final Result<VersionedPolicy> retry = await _replace(
      deviceId,
      baseVersion: latest.version,
      policy: section.write(latest.policy, value).editable,
    );
    return switch (retry) {
      Ok<VersionedPolicy>(value: final VersionedPolicy saved) => _saved(saved),
      Err<VersionedPolicy>(:final AppFailure failure) => Err<PolicySaveOutcome>(failure),
    };
  }

  Future<Result<VersionedPolicy>> _replace(
    String deviceId, {
    required int baseVersion,
    required Policy policy,
  }) {
    return _elevated<VersionedPolicy>(
      () => _policies.replace(deviceId, baseVersion: baseVersion, policy: policy),
    );
  }

  Result<PolicySaveOutcome> _saved(VersionedPolicy saved) {
    // A versao nova fica pendente no painel ate o aparelho confirmar.
    unawaited(_devices.refresh());
    return Ok<PolicySaveOutcome>(PolicySaved(saved));
  }
}
