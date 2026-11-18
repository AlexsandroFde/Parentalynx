import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/versioned_policy.dart';

/// Andamento do salvamento de uma secao.
enum SectionSaveStatus {
  /// Editando (ou nada a salvar).
  idle,

  /// Enviando ao servidor.
  saving,

  /// O servidor aceitou. Falta o aparelho confirmar.
  saved,

  /// A mesma secao mudou em outra sessao. A versao do servidor foi carregada e as alteracoes
  /// locais ficaram guardadas em [PolicySectionEditing.rejected].
  conflict,

  /// O envio falhou. As alteracoes continuam no rascunho.
  failed,
}

/// Estado de uma tela que edita uma secao da politica de um aparelho.
///
/// E o mesmo para todas as funcionalidades de regras (limite, horarios, apps, web, protecao):
/// cada uma tem os seus eventos, mas o ciclo carregar, editar, salvar e acompanhar o servidor
/// e comum.
sealed class PolicySectionState<T> extends Equatable {
  const PolicySectionState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Carregando a politica do aparelho.
final class PolicySectionLoading<T> extends PolicySectionState<T> {
  const PolicySectionLoading();
}

/// A politica nao pode ser carregada. A tela oferece tentar de novo.
final class PolicySectionError<T> extends PolicySectionState<T> {
  const PolicySectionError({required this.deviceId, required this.failure});

  final String deviceId;
  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[deviceId, failure];
}

/// Secao carregada, com o rascunho local.
final class PolicySectionEditing<T> extends PolicySectionState<T> {
  const PolicySectionEditing({
    required this.deviceId,
    required this.base,
    required this.saved,
    required this.draft,
    this.status = SectionSaveStatus.idle,
    this.failure,
    this.rejected,
  });

  final String deviceId;

  /// Versao do servidor sobre a qual se edita.
  final VersionedPolicy base;

  /// Valor da secao na versao [base].
  final T saved;

  /// Valor com as alteracoes locais ainda nao enviadas.
  final T draft;
  final SectionSaveStatus status;

  /// Motivo da ultima falha de envio, quando [status] e [SectionSaveStatus.failed].
  final AppFailure? failure;

  /// Alteracoes recusadas pelo ultimo conflito, quando [status] e
  /// [SectionSaveStatus.conflict]: a pessoa pode refaze-las sobre a versao nova.
  final T? rejected;

  /// Verdadeiro quando ha alteracoes locais nao salvas.
  bool get isDirty => draft != saved;

  bool get isSaving => status == SectionSaveStatus.saving;

  PolicySectionEditing<T> copyWith({
    VersionedPolicy? base,
    T? saved,
    T? draft,
    SectionSaveStatus? status,
    AppFailure? failure,
    T? rejected,
  }) {
    return PolicySectionEditing<T>(
      deviceId: deviceId,
      base: base ?? this.base,
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      status: status ?? this.status,
      failure: failure,
      rejected: rejected,
    );
  }

  @override
  List<Object?> get props => <Object?>[deviceId, base, saved, draft, status, failure, rejected];
}
