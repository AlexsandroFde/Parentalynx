part of 'day_timeline_bloc.dart';

sealed class DayTimelineEvent extends Equatable {
  const DayTimelineEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu para um aparelho, opcionalmente em um dia escolhido.
final class DayTimelineStarted extends DayTimelineEvent {
  const DayTimelineStarted({required this.deviceId, required this.deviceToday, this.initialDay});

  final String deviceId;

  /// Dia da cota corrente informado pelo servidor. Vazio quando ainda nao ha.
  final String deviceToday;

  /// Dia pedido pela navegacao (AAAA-MM-DD). Nulo abre o dia corrente.
  final String? initialDay;

  @override
  List<Object?> get props => <Object?>[deviceId, deviceToday, initialDay];
}

/// Mostrar o dia anterior.
final class DayTimelinePreviousDayRequested extends DayTimelineEvent {
  const DayTimelinePreviousDayRequested();
}

/// Mostrar o dia seguinte (nunca passa do dia corrente).
final class DayTimelineNextDayRequested extends DayTimelineEvent {
  const DayTimelineNextDayRequested();
}

/// Mostrar um dia escolhido no calendario (ou voltar para hoje). Nunca passa do dia corrente.
final class DayTimelineDaySelected extends DayTimelineEvent {
  const DayTimelineDaySelected(this.day);

  /// Dia (AAAA-MM-DD).
  final String day;

  @override
  List<Object?> get props => <Object?>[day];
}

/// Recarregar o dia mostrado (puxar para atualizar) sem apagar a linha do tempo da tela.
///
/// [completer] recebe a falha, ou nulo quando deu certo. Nao entra na comparacao do evento.
final class DayTimelineRefreshRequested extends DayTimelineEvent {
  const DayTimelineRefreshRequested({this.completer});

  final Completer<AppFailure?>? completer;
}

/// Tentar de novo depois de uma falha.
final class DayTimelineRetried extends DayTimelineEvent {
  const DayTimelineRetried();
}
