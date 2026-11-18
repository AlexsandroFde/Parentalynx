part of 'guardian_dashboard_bloc.dart';

sealed class GuardianDashboardEvent extends Equatable {
  const GuardianDashboardEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O aparelho em foco mudou (ou o painel abriu com um aparelho em foco).
final class DashboardDeviceSelected extends GuardianDashboardEvent {
  const DashboardDeviceSelected(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Puxar para atualizar: recarrega os apps mais usados e os alertas recentes. [completer] e
/// concluido ao terminar. Nao entra na comparacao do evento.
final class DashboardRefreshRequested extends GuardianDashboardEvent {
  const DashboardRefreshRequested({this.completer});

  final Completer<void>? completer;
}

/// Conceder minutos extras para hoje.
final class DashboardExtraTimeRequested extends GuardianDashboardEvent {
  const DashboardExtraTimeRequested(this.minutes);

  final int minutes;

  @override
  List<Object?> get props => <Object?>[minutes];
}

/// Pausar o aparelho agora. Sem [duration], ate o responsavel retomar.
final class DashboardPauseRequested extends GuardianDashboardEvent {
  const DashboardPauseRequested({this.duration});

  final Duration? duration;

  @override
  List<Object?> get props => <Object?>[duration];
}

/// Encerrar a pausa.
final class DashboardResumeRequested extends GuardianDashboardEvent {
  const DashboardResumeRequested();
}

/// Suspender regras por alguns minutos.
final class DashboardSuspendRequested extends GuardianDashboardEvent {
  const DashboardSuspendRequested({required this.minutes, required this.scopes});

  final int minutes;
  final List<SuspensionScope> scopes;

  @override
  List<Object?> get props => <Object?>[minutes, scopes];
}

/// Encerrar a suspensao de regras.
final class DashboardSuspensionEndRequested extends GuardianDashboardEvent {
  const DashboardSuspensionEndRequested();
}

/// O aparelho em foco mudou na lista da conta (sincronizou, mudou de versao de politica).
final class _DashboardDeviceChanged extends GuardianDashboardEvent {
  const _DashboardDeviceChanged(this.device);

  final ChildDevice? device;

  @override
  List<Object?> get props => <Object?>[device];
}

/// Recarregar a politica (versao nova no servidor).
final class _DashboardPolicyReloadRequested extends GuardianDashboardEvent {
  const _DashboardPolicyReloadRequested();
}

/// Recarregar os apps mais usados (o aparelho sincronizou de novo).
final class _DashboardAppsReloadRequested extends GuardianDashboardEvent {
  const _DashboardAppsReloadRequested();
}

/// Recarregar os alertas recentes (chegou um alerta novo).
final class _DashboardAlertsReloadRequested extends GuardianDashboardEvent {
  const _DashboardAlertsReloadRequested();
}
