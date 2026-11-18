import 'package:equatable/equatable.dart';

import '../../../../core/time/formatters.dart';

/// Atalhos de periodo dos relatorios.
enum ReportPreset {
  today('Hoje'),
  yesterday('Ontem'),
  last7('7 dias'),
  last30('30 dias'),
  custom('Personalizado');

  const ReportPreset(this.label);

  final String label;
}

/// Intervalo de dias da cota de um relatorio, inclusivo nas duas pontas.
final class ReportPeriod extends Equatable {
  const ReportPeriod._(this.preset, this.from, this.to);

  /// Periodo de um atalho, calculado a partir do dia da cota corrente do aparelho.
  factory ReportPeriod.preset(ReportPreset preset, {required String today}) {
    return switch (preset) {
      ReportPreset.today => ReportPeriod._(preset, today, today),
      ReportPreset.yesterday => ReportPeriod._(preset, addDays(today, -1), addDays(today, -1)),
      ReportPreset.last7 => ReportPeriod._(preset, addDays(today, -6), today),
      ReportPreset.last30 => ReportPeriod._(preset, addDays(today, -29), today),
      ReportPreset.custom => ReportPeriod._(preset, addDays(today, -6), today),
    };
  }

  /// Periodo escolhido a mao. Inverte as pontas se vierem trocadas, nao passa de [today] e
  /// corta no maximo de dias aceito pelo servidor, mantendo o fim.
  factory ReportPeriod.custom(String from, String to, {required String today}) {
    String start = from.compareTo(to) <= 0 ? from : to;
    String end = from.compareTo(to) <= 0 ? to : from;
    if (end.compareTo(today) > 0) {
      end = today;
    }
    if (start.compareTo(end) > 0) {
      start = end;
    }
    if (daysBetweenInclusive(start, end) > maxDays) {
      start = addDays(end, -(maxDays - 1));
    }
    return ReportPeriod._(ReportPreset.custom, start, end);
  }

  /// Maximo de dias em uma consulta (protocolo, secao 6).
  static const int maxDays = 92;

  final ReportPreset preset;
  final String from;
  final String to;

  int get days => daysBetweenInclusive(from, to);

  bool get isSingleDay => from == to;

  @override
  List<Object?> get props => <Object?>[preset, from, to];
}

/// Escolha de periodo feita na tela: um atalho, ou um intervalo personalizado.
final class ReportSelection extends Equatable {
  const ReportSelection({this.preset = ReportPreset.last7, this.customFrom, this.customTo});

  /// Escolha padrao ao abrir os relatorios: os ultimos 7 dias.
  static const ReportSelection initial = ReportSelection();

  final ReportPreset preset;
  final String? customFrom;
  final String? customTo;

  /// Periodo da escolha no dia da cota informado.
  ReportPeriod periodFor(String today) {
    final String? from = customFrom;
    final String? to = customTo;
    if (preset == ReportPreset.custom && from != null && to != null) {
      return ReportPeriod.custom(from, to, today: today);
    }
    return ReportPeriod.preset(preset, today: today);
  }

  @override
  List<Object?> get props => <Object?>[preset, customFrom, customTo];
}

/// Dia da cota corrente do aparelho. Quando o servidor ainda nao informou, usa a data local.
String quotaDayOf(String deviceToday, DateTime now) {
  return deviceToday.isEmpty ? formatDay(now) : deviceToday;
}
