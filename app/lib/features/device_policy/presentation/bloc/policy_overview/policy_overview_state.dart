part of 'policy_overview_bloc.dart';

/// Politica do aparelho em foco, para a visao geral das regras.
sealed class PolicyOverviewState extends Equatable {
  const PolicyOverviewState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Carregando a politica.
final class PolicyOverviewLoading extends PolicyOverviewState {
  const PolicyOverviewLoading();
}

/// A politica nao pode ser carregada. A tela oferece tentar de novo.
final class PolicyOverviewError extends PolicyOverviewState {
  const PolicyOverviewError({required this.deviceId, required this.failure});

  final String deviceId;
  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[deviceId, failure];
}

/// Politica carregada. Acompanha as versoes novas do servidor sem voltar a carregar.
final class PolicyOverviewLoaded extends PolicyOverviewState {
  const PolicyOverviewLoaded({required this.deviceId, required this.policy});

  final String deviceId;
  final VersionedPolicy policy;

  @override
  List<Object?> get props => <Object?>[deviceId, policy];
}
