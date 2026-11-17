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
class ReportPeriod {
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

  /// Descricao do intervalo: `ter 17/11` ou `11/11 a 17/11`.
  String get rangeLabel {
    if (isSingleDay) {
      return formatDayLabel(from);
    }
    return '${formatShortDate(parseDay(from))} a ${formatShortDate(parseDay(to))}';
  }

  @override
  bool operator ==(Object other) {
    return other is ReportPeriod && other.preset == preset && other.from == from && other.to == to;
  }

  @override
  int get hashCode => Object.hash(preset, from, to);
}

/// Escala do eixo de duracoes de um grafico: intervalo entre marcas e topo, em minutos.
///
/// As marcas caem em valores redondos (15min, 30min, 1h, 2h, 4h), com no maximo cerca de
/// cinco linhas.
({double interval, double max}) durationAxis(double maxMinutes) {
  const List<double> steps = <double>[5, 10, 15, 30, 60, 120, 240, 480];
  double interval = steps.last;
  for (final double step in steps) {
    if (maxMinutes / step <= 4) {
      interval = step;
      break;
    }
  }
  final double top = maxMinutes <= 0 ? interval : (maxMinutes / interval).ceil() * interval;
  return (interval: interval, max: top);
}

/// Rotulo de uma marca do eixo de duracoes: `0`, `30min`, `1h`, `1h 30min`.
String durationTick(double minutes) {
  final int value = minutes.round();
  return value == 0 ? '0' : formatMinutes(value);
}
