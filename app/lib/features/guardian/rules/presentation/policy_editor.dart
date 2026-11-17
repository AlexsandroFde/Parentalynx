import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../shared/domain/policy.dart';
import '../../apps/data/apps_repository.dart' show noRetry;
import '../../devices/data/devices_repository.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';

/// Resultado de uma tentativa de salvar as regras.
enum PolicySaveResult {
  /// O servidor aceitou a nova versao. Falta o aparelho confirmar.
  saved,

  /// Outra sessao alterou as regras durante a edicao. O rascunho foi descartado e a versao
  /// atual do servidor foi carregada.
  conflictReloaded,
}

const DeepCollectionEquality _equality = DeepCollectionEquality();

/// Compara duas politicas ignorando `overrides`, que so mudam pelas rotas de comando.
bool sameEditablePolicy(Policy a, Policy b) {
  return _equality.equals(
    a.toJsonWith(includeOverrides: false),
    b.toJsonWith(includeOverrides: false),
  );
}

/// Politica de um aparelho em edicao: a versao do servidor e o rascunho local.
class PolicyEditorState {
  const PolicyEditorState({required this.saved, required this.draft, this.saving = false});

  /// Ultima versao conhecida do servidor.
  final DevicePolicy saved;

  /// Politica com as alteracoes locais ainda nao enviadas.
  final Policy draft;
  final bool saving;

  /// Verdadeiro quando ha alteracoes locais nao salvas.
  bool get isDirty => !sameEditablePolicy(draft, saved.policy);

  PolicyEditorState copyWith({DevicePolicy? saved, Policy? draft, bool? saving}) {
    return PolicyEditorState(
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      saving: saving ?? this.saving,
    );
  }
}

/// Editor da politica de um aparelho, por identificador do aparelho.
///
/// As telas de regras alteram o rascunho com [PolicyEditor.edit] e gravam com
/// [PolicyEditor.save]. O rascunho de cada aparelho fica em memoria enquanto o app estiver
/// aberto.
final AsyncNotifierProviderFamily<PolicyEditor, PolicyEditorState, String> policyEditorProvider =
    AsyncNotifierProvider.family<PolicyEditor, PolicyEditorState, String>(
      PolicyEditor.new,
      retry: noRetry,
    );

class PolicyEditor extends AsyncNotifier<PolicyEditorState> {
  PolicyEditor(this.deviceId);

  final String deviceId;
  bool _syncing = false;

  @override
  Future<PolicyEditorState> build() async {
    // Quando o servidor passa a ter uma versao mais nova (comando do painel, outra sessao),
    // acompanha sem perder o que esta sendo editado.
    ref.listen<AsyncValue<List<Device>>>(devicesProvider, (
      AsyncValue<List<Device>>? previous,
      AsyncValue<List<Device>> next,
    ) {
      final Device? device = next.value?.firstWhereOrNull((Device item) => item.id == deviceId);
      final PolicyEditorState? current = state.value;
      if (device == null || current == null || current.saving || _syncing) {
        return;
      }
      if (device.policyVersion > current.saved.version) {
        unawaited(_syncWithServer());
      }
    });
    final DeviceDetail detail = await ref.read(devicesRepositoryProvider).getDevice(deviceId);
    return PolicyEditorState(saved: detail.policy, draft: detail.policy.policy);
  }

  /// Aplica uma alteracao ao rascunho.
  void edit(Policy Function(Policy current) change) {
    final PolicyEditorState? current = state.value;
    if (current == null || current.saving) {
      return;
    }
    state = AsyncData<PolicyEditorState>(current.copyWith(draft: change(current.draft)));
  }

  /// Descarta as alteracoes locais.
  void discard() {
    final PolicyEditorState? current = state.value;
    if (current == null || current.saving) {
      return;
    }
    state = AsyncData<PolicyEditorState>(current.copyWith(draft: current.saved.policy));
  }

  /// Busca a politica de novo no servidor, descartando o rascunho.
  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  /// Envia o rascunho ao servidor.
  ///
  /// Lanca a falha original quando o envio nao e aceito (inclusive `elevation_required`, para
  /// quem chama pedir a senha e repetir). Conflito de versao e resolvido aqui: se so os
  /// comandos mudaram no servidor, reenvia sobre a versao nova; se as regras mudaram, carrega
  /// a versao do servidor e devolve [PolicySaveResult.conflictReloaded].
  Future<PolicySaveResult> save() async {
    final PolicyEditorState current = state.requireValue;
    if (!current.isDirty) {
      return PolicySaveResult.saved;
    }
    final DevicesRepository repository = ref.read(devicesRepositoryProvider);
    state = AsyncData<PolicyEditorState>(current.copyWith(saving: true));
    try {
      final DevicePolicy updated = await repository.updatePolicy(
        deviceId,
        baseVersion: current.saved.version,
        policy: current.draft,
      );
      _accept(updated);
      return PolicySaveResult.saved;
    } on ApiFailure catch (failure) {
      if (!failure.isVersionConflict) {
        _restore(current);
        rethrow;
      }
    } on Object {
      _restore(current);
      rethrow;
    }

    try {
      final DevicePolicy latest = (await repository.getDevice(deviceId)).policy;
      if (sameEditablePolicy(latest.policy, current.saved.policy)) {
        final DevicePolicy updated = await repository.updatePolicy(
          deviceId,
          baseVersion: latest.version,
          policy: current.draft,
        );
        _accept(updated);
        return PolicySaveResult.saved;
      }
      if (ref.mounted) {
        state = AsyncData<PolicyEditorState>(
          PolicyEditorState(saved: latest, draft: latest.policy),
        );
      }
      return PolicySaveResult.conflictReloaded;
    } on Object {
      _restore(current);
      rethrow;
    }
  }

  void _accept(DevicePolicy updated) {
    if (!ref.mounted) {
      return;
    }
    state = AsyncData<PolicyEditorState>(PolicyEditorState(saved: updated, draft: updated.policy));
    // Atualiza a lista para o painel mostrar a versao nova como pendente no aparelho.
    unawaited(ref.read(devicesProvider.notifier).refresh());
  }

  void _restore(PolicyEditorState previous) {
    if (ref.mounted) {
      state = AsyncData<PolicyEditorState>(previous.copyWith(saving: false));
    }
  }

  Future<void> _syncWithServer() async {
    _syncing = true;
    try {
      final DevicePolicy latest = (await ref.read(devicesRepositoryProvider).getDevice(deviceId))
          .policy;
      if (!ref.mounted) {
        return;
      }
      final PolicyEditorState? current = state.value;
      if (current == null || current.saving || latest.version <= current.saved.version) {
        return;
      }
      if (!current.isDirty) {
        state = AsyncData<PolicyEditorState>(
          PolicyEditorState(saved: latest, draft: latest.policy),
        );
      } else if (sameEditablePolicy(latest.policy, current.saved.policy)) {
        // So os comandos mudaram: o rascunho continua valido sobre a versao nova.
        state = AsyncData<PolicyEditorState>(
          current.copyWith(
            saved: latest,
            draft: current.draft.copyWith(overrides: latest.policy.overrides),
          ),
        );
      }
      // Regras alteradas em outro lugar durante a edicao: o conflito aparece ao salvar.
    } on Object {
      // Falha ao atualizar em segundo plano: mantem o que esta na tela.
    } finally {
      _syncing = false;
    }
  }
}
