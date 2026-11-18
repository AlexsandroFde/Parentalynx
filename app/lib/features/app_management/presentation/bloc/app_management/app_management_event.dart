part of 'app_management_bloc.dart';

sealed class AppManagementEvent extends Equatable {
  const AppManagementEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela de apps abriu para um aparelho (ou a pessoa pediu para tentar de novo).
final class AppManagementStarted extends AppManagementEvent {
  const AppManagementStarted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Troca a regra de um app (folha do app, remover das excecoes).
final class AppRuleChanged extends AppManagementEvent {
  const AppRuleChanged({required this.app, required this.rule});

  final KnownApp app;
  final AppRule rule;

  @override
  List<Object?> get props => <Object?>[app, rule];
}

/// Aplica o mesmo estado a todos os apps listados ("Aplicar a todos").
final class AppRulesAppliedToMany extends AppManagementEvent {
  const AppRulesAppliedToMany({required this.apps, required this.state});

  final List<KnownApp> apps;
  final AppRuleState state;

  @override
  List<Object?> get props => <Object?>[apps, state];
}

/// Troca o padrao para apps instalados depois, sem mudar os ja instalados.
final class NewAppDefaultChanged extends AppManagementEvent {
  const NewAppDefaultChanged({required this.value, required this.installedApps});

  final NewAppDefault value;
  final List<KnownApp> installedApps;

  @override
  List<Object?> get props => <Object?>[value, installedApps];
}

/// Envia o rascunho ao servidor.
final class AppManagementSaveRequested extends AppManagementEvent {
  const AppManagementSaveRequested();
}

/// Descarta as alteracoes locais.
final class AppManagementDiscardRequested extends AppManagementEvent {
  const AppManagementDiscardRequested();
}

/// O servidor informou uma versao nova da politica do aparelho.
final class _AppManagementServerVersionChanged extends AppManagementEvent {
  const _AppManagementServerVersionChanged(this.version);

  final int version;

  @override
  List<Object?> get props => <Object?>[version];
}
