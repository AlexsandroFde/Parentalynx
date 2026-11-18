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
