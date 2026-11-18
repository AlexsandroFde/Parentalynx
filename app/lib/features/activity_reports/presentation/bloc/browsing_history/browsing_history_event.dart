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

/// Carregar a pagina seguinte.
final class BrowsingHistoryMoreRequested extends BrowsingHistoryEvent {
  const BrowsingHistoryMoreRequested();
}

/// Tentar de novo depois de uma falha (da primeira pagina ou da seguinte).
final class BrowsingHistoryRetried extends BrowsingHistoryEvent {
  const BrowsingHistoryRetried();
}
