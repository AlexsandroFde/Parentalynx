/// Formatacao de duracoes, horarios e dias em portugues do Brasil.
///
/// Funcoes puras, sem dependencia de localizacao carregada, para poderem ser usadas em
/// qualquer camada e em testes.
library;

const List<String> weekdayShortNames = <String>['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

const List<String> weekdayLongNames = <String>[
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

/// Nome curto do dia da semana ISO (1 = segunda, 7 = domingo).
String weekdayShort(int isoWeekday) => weekdayShortNames[(isoWeekday - 1) % 7];

String weekdayLong(int isoWeekday) => weekdayLongNames[(isoWeekday - 1) % 7];

/// Duracao legivel: `2h 30min`, `45min`, `1h`, `menos de 1min`, `0min`.
String formatDurationMs(int ms) {
  if (ms <= 0) {
    return '0min';
  }
  final int totalMinutes = ms ~/ 60000;
  if (totalMinutes == 0) {
    return 'menos de 1min';
  }
  return formatMinutes(totalMinutes);
}

/// Minutos legiveis: `2h 30min`, `45min`, `1h`.
String formatMinutes(int minutes) {
  if (minutes <= 0) {
    return '0min';
  }
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours == 0) {
    return '${rest}min';
  }
  if (rest == 0) {
    return '${hours}h';
  }
  return '${hours}h ${rest}min';
}

/// Contagem regressiva com segundos, para o tempo restante: `1:05:09` ou `05:09`.
String formatCountdown(int ms) {
  final int totalSeconds = ms <= 0 ? 0 : ms ~/ 1000;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String mm = minutes.toString().padLeft(2, '0');
  final String ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Horario `HH:mm`.
String formatClock(DateTime time) {
  final String hh = time.hour.toString().padLeft(2, '0');
  final String mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Horario `HH:mm` de um instante em milissegundos, no fuso do aparelho.
String formatClockMs(int epochMs) => formatClock(DateTime.fromMillisecondsSinceEpoch(epochMs));

/// Data curta `17/11`.
String formatShortDate(DateTime date) {
  final String dd = date.day.toString().padLeft(2, '0');
  final String mm = date.month.toString().padLeft(2, '0');
  return '$dd/$mm';
}

/// Data e hora relativas ao momento atual: `agora`, `há 5 min`, `há 2 h`, `ontem às 14:30`,
/// `12/11 às 09:00`.
String formatRelative(DateTime time, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final Duration diff = reference.difference(time);
  if (diff.isNegative) {
    return _absolute(time, reference);
  }
  if (diff.inSeconds < 60) {
    return 'agora';
  }
  if (diff.inMinutes < 60) {
    return 'há ${diff.inMinutes} min';
  }
  final DateTime today = DateTime(reference.year, reference.month, reference.day);
  final DateTime thatDay = DateTime(time.year, time.month, time.day);
  final int dayGap = today.difference(thatDay).inDays;
  if (dayGap == 0) {
    return 'há ${diff.inHours} h';
  }
  if (dayGap == 1) {
    return 'ontem às ${formatClock(time)}';
  }
  return _absolute(time, reference);
}

String formatRelativeMs(int epochMs, {DateTime? now}) {
  return formatRelative(DateTime.fromMillisecondsSinceEpoch(epochMs), now: now);
}

String _absolute(DateTime time, DateTime reference) {
  final String date = time.year == reference.year
      ? formatShortDate(time)
      : '${formatShortDate(time)}/${time.year}';
  return '$date às ${formatClock(time)}';
}

/// Quando um bloqueio termina, em relacao a agora: `às 07:00`, `amanhã às 07:00`,
/// `17/11 às 07:00`.
String formatReleaseTime(int epochMs, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final DateTime time = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final DateTime today = DateTime(reference.year, reference.month, reference.day);
  final DateTime thatDay = DateTime(time.year, time.month, time.day);
  final int dayGap = thatDay.difference(today).inDays;
  if (dayGap == 0) {
    return 'às ${formatClock(time)}';
  }
  if (dayGap == 1) {
    return 'amanhã às ${formatClock(time)}';
  }
  return '${formatShortDate(time)} às ${formatClock(time)}';
}

// Dias da cota: texto `AAAA-MM-DD`. As contas usam UTC para nao sofrer com horario de verao.

/// Interpreta `AAAA-MM-DD` como uma data em UTC a meia-noite.
DateTime parseDay(String day) {
  final List<String> parts = day.split('-');
  if (parts.length != 3) {
    throw FormatException('Dia invalido: $day');
  }
  return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

String formatDay(DateTime date) {
  final String yyyy = date.year.toString().padLeft(4, '0');
  final String mm = date.month.toString().padLeft(2, '0');
  final String dd = date.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

/// Soma (ou subtrai) dias a um dia da cota.
String addDays(String day, int amount) => formatDay(parseDay(day).add(Duration(days: amount)));

/// Dias entre dois dias da cota, inclusive nas duas pontas.
int daysBetweenInclusive(String from, String to) {
  return parseDay(to).difference(parseDay(from)).inDays + 1;
}

/// Dia da semana ISO (1 = segunda) de um dia da cota.
int weekdayOfDay(String day) => parseDay(day).weekday;

/// Rotulo curto de um dia da cota: `seg 17/11`.
String formatDayLabel(String day) {
  final DateTime date = parseDay(day);
  return '${weekdayShort(date.weekday)} ${formatShortDate(date)}';
}

/// Rotulo de um dia em relacao a hoje: `Hoje`, `Ontem` ou `seg 17/11`.
String formatDayRelative(String day, {required String today}) {
  if (day == today) {
    return 'Hoje';
  }
  if (day == addDays(today, -1)) {
    return 'Ontem';
  }
  return formatDayLabel(day);
}
