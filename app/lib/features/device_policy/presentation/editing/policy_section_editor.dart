import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/domain/usecases/watch_child_devices.dart';
import '../../domain/entities/policy_save_outcome.dart';
import '../../domain/entities/policy_section.dart';
import '../../domain/entities/versioned_policy.dart';
import '../../domain/usecases/get_device_policy.dart';
import '../../domain/usecases/save_policy_section.dart';
import 'policy_section_state.dart';

/// Ciclo comum das telas que editam uma secao da politica: carregar, editar, descartar,
/// salvar e acompanhar versoes novas do servidor.
///
/// Os BLoCs de regras usam esta classe por composicao: cada um traduz os seus eventos em
/// alteracoes da secao e delega o resto. As regras de versao e conflito ficam no caso de uso
/// [SavePolicySection]; aqui so se monta o estado da tela.
final class PolicySectionEditor<T> {
  PolicySectionEditor({
    required this.section,
    required this._getDevicePolicy,
    required this._savePolicySection,
    required this._watchDevices,
  });

  final PolicySection<T> section;
  final GetDevicePolicy _getDevicePolicy;
  final SavePolicySection _savePolicySection;
  final WatchChildDevices _watchDevices;

  /// Carrega a politica do aparelho e abre a secao para edicao.
  Future<PolicySectionState<T>> load(String deviceId) async {
    final Result<VersionedPolicy> result = await _getDevicePolicy(deviceId);
    return switch (result) {
      Ok<VersionedPolicy>(:final VersionedPolicy value) => _editing(deviceId, value),
      Err<VersionedPolicy>(:final AppFailure failure) => PolicySectionError<T>(
        deviceId: deviceId,
        failure: failure,
      ),
    };
  }

  /// Aplica uma alteracao ao rascunho. Durante o envio o rascunho fica parado.
  PolicySectionState<T> edit(PolicySectionState<T> state, T Function(T current) change) {
    if (state is! PolicySectionEditing<T> || state.isSaving) {
      return state;
    }
    return state.copyWith(draft: change(state.draft), status: SectionSaveStatus.idle);
  }

  /// Descarta as alteracoes locais.
  PolicySectionState<T> discard(PolicySectionState<T> state) {
    if (state is! PolicySectionEditing<T> || state.isSaving) {
      return state;
    }
    return state.copyWith(draft: state.saved, status: SectionSaveStatus.idle);
  }

  /// Estado de "enviando", ou nulo quando nao ha o que salvar.
  PolicySectionEditing<T>? startSaving(PolicySectionState<T> state) {
    if (state is! PolicySectionEditing<T> || state.isSaving || !state.isDirty) {
      return null;
    }
    return state.copyWith(status: SectionSaveStatus.saving);
  }

  /// Envia o rascunho. Recebe o estado devolvido por [startSaving].
  Future<PolicySectionState<T>> save(PolicySectionEditing<T> saving) async {
    final Result<PolicySaveOutcome> result = await _savePolicySection<T>(
      deviceId: saving.deviceId,
      base: saving.base,
      value: saving.draft,
      section: section,
    );
    switch (result) {
      case Ok<PolicySaveOutcome>(value: PolicySaved(:final VersionedPolicy policy)):
        return _editing(saving.deviceId, policy, status: SectionSaveStatus.saved);
      case Ok<PolicySaveOutcome>(value: PolicyConflict(:final VersionedPolicy latest)):
        return _editing(saving.deviceId, latest, status: SectionSaveStatus.conflict);
      case Err<PolicySaveOutcome>(failure: CancelledFailure()):
        // A pessoa desistiu de confirmar a senha: volta a editar, sem aviso.
        return saving.copyWith(status: SectionSaveStatus.idle);
      case Err<PolicySaveOutcome>(:final AppFailure failure):
        return saving.copyWith(status: SectionSaveStatus.failed, failure: failure);
    }
  }

  /// Versoes da politica que o servidor informa para o aparelho (pela lista de aparelhos).
  Stream<int> serverVersions(String deviceId) {
    return _watchDevices
        .device(deviceId)
        .where((ChildDevice? device) => device != null)
        .map((ChildDevice? device) => device!.policyVersion)
        .distinct();
  }

  /// Acompanha uma versao nova do servidor (comando do painel, outra sessao) sem perder o que
  /// esta sendo editado. Devolve nulo quando nada muda na tela.
  Future<PolicySectionState<T>?> follow(PolicySectionState<T> state, int serverVersion) async {
    if (state is! PolicySectionEditing<T> ||
        state.isSaving ||
        serverVersion <= state.base.version) {
      return null;
    }
    final Result<VersionedPolicy> result = await _getDevicePolicy(state.deviceId);
    final VersionedPolicy? latest = result.valueOrNull;
    if (latest == null || latest.version <= state.base.version) {
      // Falha em segundo plano: mantem o que esta na tela.
      return null;
    }
    final T remote = section.read(latest.policy);
    if (!state.isDirty) {
      return _editing(state.deviceId, latest);
    }
    if (remote == state.saved) {
      // A secao nao mudou no servidor: o rascunho continua valido sobre a versao nova.
      return state.copyWith(base: latest);
    }
    // A secao mudou em outro lugar durante a edicao: o conflito aparece ao salvar.
    return null;
  }

  PolicySectionEditing<T> _editing(
    String deviceId,
    VersionedPolicy policy, {
    SectionSaveStatus status = SectionSaveStatus.idle,
  }) {
    final T value = section.read(policy.policy);
    return PolicySectionEditing<T>(
      deviceId: deviceId,
      base: policy,
      saved: value,
      draft: value,
      status: status,
    );
  }
}
