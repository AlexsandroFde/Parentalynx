part of 'device_events_bloc.dart';

sealed class DeviceEventsEvent extends Equatable {
  const DeviceEventsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu para um aparelho e um periodo. Sem periodo, mostra os ultimos 7 dias; sem
/// grupo, todos os eventos.
final class DeviceEventsStarted extends DeviceEventsEvent {
  const DeviceEventsStarted({
    required this.deviceId,
    required this.deviceToday,
    this.from,
    this.to,
    this.group,
  });

  final String deviceId;
  final String deviceToday;
  final String? from;
  final String? to;

  /// Grupo pedido pela navegacao (por exemplo, so os bloqueios a partir do relatorio).
  final EventGroup? group;

  @override
  List<Object?> get props => <Object?>[deviceId, deviceToday, from, to, group];
}

/// A pessoa escolheu um grupo de eventos (Bloqueios, Limite, Seguranca...).
final class DeviceEventsGroupSelected extends DeviceEventsEvent {
  const DeviceEventsGroupSelected(this.group);

  final EventGroup group;

  @override
  List<Object?> get props => <Object?>[group];
}

/// A pessoa escolheu outro periodo no calendario. O periodo nao passa do dia corrente nem do
/// maximo de dias de uma consulta.
final class DeviceEventsPeriodChanged extends DeviceEventsEvent {
  const DeviceEventsPeriodChanged({required this.from, required this.to});

  final String from;
  final String to;

  @override
  List<Object?> get props => <Object?>[from, to];
}

/// Recarregar a primeira pagina (puxar para atualizar) sem apagar a lista da tela.
///
/// [completer] recebe a falha, ou nulo quando deu certo. Nao entra na comparacao do evento.
final class DeviceEventsRefreshRequested extends DeviceEventsEvent {
  const DeviceEventsRefreshRequested({this.completer});

  final Completer<AppFailure?>? completer;
}

/// Carregar a pagina seguinte.
final class DeviceEventsMoreRequested extends DeviceEventsEvent {
  const DeviceEventsMoreRequested();
}

/// Tentar de novo depois de uma falha (da primeira pagina ou da seguinte).
final class DeviceEventsRetried extends DeviceEventsEvent {
  const DeviceEventsRetried();
}
