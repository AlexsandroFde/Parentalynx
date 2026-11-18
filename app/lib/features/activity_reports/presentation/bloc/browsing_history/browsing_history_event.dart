part of 'browsing_history_bloc.dart';

sealed class BrowsingHistoryEvent extends Equatable {
  const BrowsingHistoryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu para um aparelho e um periodo. Sem periodo, mostra os ultimos 7 dias.
final class BrowsingHistoryStarted extends BrowsingHistoryEvent {
  const BrowsingHistoryStarted({
    required this.deviceId,
    required this.deviceToday,
    this.from,
    this.to,
  });

  final String deviceId;
  final String deviceToday;
  final String? from;
  final String? to;

  @override
  List<Object?> get props => <Object?>[deviceId, deviceToday, from, to];
}

/// Mostrar so as paginas bloqueadas, ou todas.
final class BrowsingHistoryOnlyBlockedChanged extends BrowsingHistoryEvent {
  const BrowsingHistoryOnlyBlockedChanged({required this.onlyBlocked});

  final bool onlyBlocked;

  @override
  List<Object?> get props => <Object?>[onlyBlocked];
}

/// Texto da busca (titulo, site ou endereco) nas paginas ja carregadas.
final class BrowsingHistoryQueryChanged extends BrowsingHistoryEvent {
  const BrowsingHistoryQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// A pessoa escolheu outro periodo no calendario. O periodo nao passa do dia corrente nem do
/// maximo de dias de uma consulta.
final class BrowsingHistoryPeriodChanged extends BrowsingHistoryEvent {
  const BrowsingHistoryPeriodChanged({required this.from, required this.to});

  final String from;
  final String to;

  @override
  List<Object?> get props => <Object?>[from, to];
}

/// Recarregar a primeira pagina (puxar para atualizar) sem apagar a lista da tela.
///
/// [completer] recebe a falha, ou nulo quando deu certo. Nao entra na comparacao do evento.
final class BrowsingHistoryRefreshRequested extends BrowsingHistoryEvent {
  const BrowsingHistoryRefreshRequested({this.completer});

  final Completer<AppFailure?>? completer;
}

/// Carregar a pagina seguinte.
final class BrowsingHistoryMoreRequested extends BrowsingHistoryEvent {
  const BrowsingHistoryMoreRequested();
}

/// Tentar de novo depois de uma falha (da primeira pagina ou da seguinte).
final class BrowsingHistoryRetried extends BrowsingHistoryEvent {
  const BrowsingHistoryRetried();
}
