import '../../../../core/time/formatters.dart';
import '../../domain/entities/report_period.dart';

/// Textos dos periodos de relatorio.
extension ReportPeriodText on ReportPeriod {
  /// Descricao do intervalo: `ter 17/11` ou `11/11 a 17/11`.
  String get rangeLabel {
    if (isSingleDay) {
      return formatDayLabel(from);
    }
    return '${formatShortDate(parseDay(from))} a ${formatShortDate(parseDay(to))}';
  }

  /// Periodo por extenso para a tela: `Hoje, ter 17/11`, `Ontem, seg 16/11`, `qua 11/11` ou
  /// `11/11 a 17/11 · 7 dias`.
  String describe({required String today}) {
    if (!isSingleDay) {
      return '$rangeLabel · $days dias';
    }
    final String label = formatDayLabel(from);
    if (from == today) {
      return 'Hoje, $label';
    }
    if (from == addDays(today, -1)) {
      return 'Ontem, $label';
    }
    return label;
  }

  /// Legenda do total: `de uso em 7 dias`, `de uso hoje`, `de uso ontem`, `de uso em qua 11/11`.
  String totalCaption({required String today}) {
    if (!isSingleDay) {
      return 'de uso em $days dias';
    }
    if (from == today) {
      return 'de uso hoje';
    }
    if (from == addDays(today, -1)) {
      return 'de uso ontem';
    }
    return 'de uso em ${formatDayLabel(from)}';
  }
}

/// Faixa de uma hora: `19h às 20h`.
String hourRangeLabel(int hour) => '${hour}h às ${hour + 1}h';

/// Contagem de aberturas: `1 abertura`, `41 aberturas`.
String opensLabel(int count) => count == 1 ? '1 abertura' : '$count aberturas';

/// Contagem de vezes: `1 vez`, `9 vezes`.
String timesLabel(int count) => count == 1 ? '1 vez' : '$count vezes';

/// De quando sao os dados do aparelho: o relatorio so mostra o uso ate a ultima vez que o
/// aparelho falou com o servidor. Sem conexao, diz que o uso mais recente ainda vai chegar.
String deviceDataFreshness({
  required int? lastSyncAt,
  required bool online,
  required DateTime now,
}) {
  if (lastSyncAt == null) {
    return 'O aparelho ainda não enviou dados de uso.';
  }
  final String when = formatRelativeMs(lastSyncAt, now: now);
  final String moment = RegExp(r'^\d').hasMatch(when) ? 'em $when' : when;
  if (online) {
    return 'Dados recebidos do aparelho $moment.';
  }
  return 'Aparelho sem conexão. Dados recebidos $moment; o uso depois disso aparece quando ele '
      'voltar a se conectar.';
}

/// Titulo do grupo de um dia nas listas: `Hoje`, `Ontem`, `seg 16/11` ou `16/11/2025`.
String dayHeading(DateTime time, {required DateTime now}) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(time.year, time.month, time.day);
  // Arredonda as horas: dias com mudanca de horario de verao tem 23 ou 25 horas.
  final int gap = (today.difference(day).inHours / 24).round();
  if (gap == 0) {
    return 'Hoje';
  }
  if (gap == 1) {
    return 'Ontem';
  }
  if (time.year != now.year) {
    return '${formatShortDate(time)}/${time.year}';
  }
  return '${weekdayShort(time.weekday)} ${formatShortDate(time)}';
}

/// Dia de uma linha do tempo em destaque: `Hoje`, `Ontem` ou `Quarta-feira`.
String timelineDayTitle(String day, {required String today}) {
  final String relative = formatDayRelative(day, today: today);
  if (relative == 'Hoje' || relative == 'Ontem') {
    return relative;
  }
  final String weekday = weekdayLong(weekdayOfDay(day));
  return '${weekday[0].toUpperCase()}${weekday.substring(1)}';
}

/// Complemento do dia em destaque: `terça-feira, 17/11` (hoje e ontem) ou `11/11`.
String timelineDaySubtitle(String day, {required String today}) {
  final DateTime date = parseDay(day);
  final String relative = formatDayRelative(day, today: today);
  if (relative == 'Hoje' || relative == 'Ontem') {
    return '${weekdayLong(date.weekday)}, ${formatShortDate(date)}';
  }
  return formatShortDate(date);
}
