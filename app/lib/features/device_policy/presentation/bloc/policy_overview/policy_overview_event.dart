part of 'policy_overview_bloc.dart';

sealed class PolicyOverviewEvent extends Equatable {
  const PolicyOverviewEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A visao geral abriu para um aparelho (ou o responsavel pediu para tentar de novo).
final class PolicyOverviewStarted extends PolicyOverviewEvent {
  const PolicyOverviewStarted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Puxar para atualizar: recarrega a lista de aparelhos e a politica.
///
/// [completer] e concluido quando a recarga termina. Nao entra na comparacao do evento.
final class PolicyOverviewRefreshRequested extends PolicyOverviewEvent {
  const PolicyOverviewRefreshRequested({this.completer});

  final Completer<void>? completer;
}

/// O servidor informou uma versao nova da politica do aparelho.
final class _PolicyOverviewServerVersionChanged extends PolicyOverviewEvent {
  const _PolicyOverviewServerVersionChanged(this.version);

  final int version;

  @override
  List<Object?> get props => <Object?>[version];
}
