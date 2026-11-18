import '../../../../core/time/formatters.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/texts/describe_days.dart';

/// Resumo do limite diario para a visao geral das regras: `2h 30min por dia`,
/// `2h 30min por dia (sáb e dom: 4h)`.
String dailyLimitSummary(DailyLimit limit) {
  if (!limit.enabled) {
    return 'Desligado';
  }
  final String base = '${formatMinutes(limit.minutes)} por dia';
  final Map<int, int> overrides = <int, int>{
    for (final MapEntry<int, int> entry in limit.perWeekday.entries)
      if (entry.value != limit.minutes) entry.key: entry.value,
  };
  if (overrides.isEmpty) {
    return base;
  }
  final Set<int> values = overrides.values.toSet();
  if (values.length == 1) {
    return '$base (${describeDays(overrides.keys)}: ${formatMinutes(values.single)})';
  }
  final int count = overrides.length;
  return '$base, com valor próprio em $count ${count == 1 ? 'dia' : 'dias'}';
}

/// Tempo de cada dia da semana agrupado por valor, para conferir a semana de uma vez:
/// `seg a sex: 2h 30min · sáb e dom: 4h`, ou `Todos os dias: 2h`.
String weekLimitsSummary(DailyLimit limit) {
  final Map<int, List<int>> daysByMinutes = <int, List<int>>{};
  for (int day = 1; day <= 7; day++) {
    daysByMinutes.putIfAbsent(limit.minutesFor(day), () => <int>[]).add(day);
  }
  if (daysByMinutes.length == 1) {
    return 'Todos os dias: ${formatMinutes(daysByMinutes.keys.single)}';
  }
  final List<MapEntry<int, List<int>>> groups = daysByMinutes.entries.toList()
    ..sort((MapEntry<int, List<int>> a, MapEntry<int, List<int>> b) {
      return a.value.first.compareTo(b.value.first);
    });
  return capitalizeFirst(
    groups
        .map((MapEntry<int, List<int>> e) => '${describeDays(e.value)}: ${formatMinutes(e.key)}')
        .join(' · '),
  );
}
