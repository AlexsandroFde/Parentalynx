import 'package:equatable/equatable.dart';

import 'versioned_policy.dart';

/// Resultado de salvar uma secao da politica.
sealed class PolicySaveOutcome extends Equatable {
  const PolicySaveOutcome();
}

/// O servidor aceitou a versao nova. Falta o aparelho confirmar que aplicou.
final class PolicySaved extends PolicySaveOutcome {
  const PolicySaved(this.policy);

  final VersionedPolicy policy;

  @override
  List<Object?> get props => <Object?>[policy];
}

/// A mesma secao foi alterada em outra sessao durante a edicao. As alteracoes locais nao
/// foram aplicadas; [latest] e a versao atual do servidor.
final class PolicyConflict extends PolicySaveOutcome {
  const PolicyConflict(this.latest);

  final VersionedPolicy latest;

  @override
  List<Object?> get props => <Object?>[latest];
}
