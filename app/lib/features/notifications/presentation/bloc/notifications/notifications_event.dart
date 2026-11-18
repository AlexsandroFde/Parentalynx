part of 'notifications_bloc.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O painel abriu: busca a contagem de nao lidos e passa a receber os alertas em tempo real.
final class NotificationsStarted extends NotificationsEvent {
  const NotificationsStarted();
}

/// A central de alertas abriu: carrega a primeira pagina, se ainda nao carregou.
final class AlertsFeedRequested extends NotificationsEvent {
  const AlertsFeedRequested();
}

/// Recarregar a primeira pagina (puxar para atualizar), mantendo a lista atual na tela se a
/// recarga falhar. [completer] e concluido ao terminar. Nao entra na comparacao do evento.
final class AlertsRefreshRequested extends NotificationsEvent {
  const AlertsRefreshRequested({this.completer});

  final Completer<void>? completer;
}

/// Carregar a pagina seguinte de alertas mais antigos.
final class OlderAlertsRequested extends NotificationsEvent {
  const OlderAlertsRequested();
}

/// A pessoa abriu um alerta: marca como lido.
final class AlertReadRequested extends NotificationsEvent {
  const AlertReadRequested(this.alertId);

  final int alertId;

  @override
  List<Object?> get props => <Object?>[alertId];
}

/// Marcar todos os alertas como lidos.
final class AllAlertsReadRequested extends NotificationsEvent {
  const AllAlertsReadRequested();
}

/// Um alerta chegou pelo canal em tempo real.
final class _IncomingAlertReceived extends NotificationsEvent {
  const _IncomingAlertReceived(this.alert);

  final GuardianAlert alert;

  @override
  List<Object?> get props => <Object?>[alert];
}
