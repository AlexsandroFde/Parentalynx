part of 'activity_reports_bloc.dart';

sealed class ActivityReportsEvent extends Equatable {
  const ActivityReportsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O aparelho em foco mudou (ou o dia da cota dele virou). Recarrega o relatorio mantendo o
/// periodo escolhido.
final class ReportsDeviceChanged extends ActivityReportsEvent {
  const ReportsDeviceChanged({required this.deviceId, required this.deviceToday});

  final String deviceId;

  /// Dia da cota corrente informado pelo servidor. Vazio quando ainda nao ha.
  final String deviceToday;

  @override
  List<Object?> get props => <Object?>[deviceId, deviceToday];
}

/// A pessoa escolheu um atalho de periodo (Hoje, Ontem, 7 dias, 30 dias).
final class ReportsPresetSelected extends ActivityReportsEvent {
  const ReportsPresetSelected(this.preset);

  final ReportPreset preset;

  @override
  List<Object?> get props => <Object?>[preset];
}

/// A pessoa escolheu um intervalo personalizado no calendario.
final class ReportsCustomRangeSelected extends ActivityReportsEvent {
  const ReportsCustomRangeSelected({required this.from, required this.to});

  final String from;
  final String to;

  @override
  List<Object?> get props => <Object?>[from, to];
}

/// Recarregar o relatorio atual (puxar para atualizar, tentar de novo).
///
/// [completer] e concluido quando a recarga termina. Nao entra na comparacao do evento.
final class ReportsRefreshRequested extends ActivityReportsEvent {
  const ReportsRefreshRequested({this.completer});

  final Completer<void>? completer;
}
