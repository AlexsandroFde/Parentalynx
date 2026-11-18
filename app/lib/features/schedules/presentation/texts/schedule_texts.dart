import '../../../../core/time/formatters.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/texts/describe_days.dart';
import '../../domain/entities/day_window.dart';
import '../../domain/services/allowed_hours_editing.dart';

/// Resumo dos horarios permitidos para a visao geral das regras.
String allowedHoursSummary(AllowedHours hours) {
  if (!hours.enabled) {
    return 'Sem restrição de horário';
  }
  final WeekWindows byDay = expandAllowedHours(hours);
  final List<DayWindow> first = byDay[1] ?? const <DayWindow>[];
  bool sameEveryDay = first.isNotEmpty;
  for (int day = 2; day <= 7 && sameEveryDay; day++) {
    final List<DayWindow> list = byDay[day] ?? const <DayWindow>[];
    sameEveryDay = list.length == first.length;
    for (int i = 0; i < list.length && sameEveryDay; i++) {
      sameEveryDay = list[i] == first[i];
    }
  }
  if (sameEveryDay) {
    return first.length == 1
        ? 'Todos os dias, ${first.single}'
        : 'Todos os dias, ${first.length} janelas';
  }
  final int blocked = blockedDays(byDay).length;
  if (blocked == 7) {
    return 'Nenhum horário liberado: bloqueado todos os dias';
  }
  if (blocked == 0) {
    return 'Horários definidos por dia da semana';
  }
  return 'Horários por dia, $blocked ${blocked == 1 ? 'dia' : 'dias'} sem uso liberado';
}

/// Descreve quando um periodo de bloqueio vale.
String describeBlockPeriod(BlockPeriod period) {
  if (period.kind == BlockPeriodKind.once) {
    final DateTime start = DateTime.fromMillisecondsSinceEpoch(period.startAt ?? 0);
    final DateTime end = DateTime.fromMillisecondsSinceEpoch(period.endAt ?? 0);
    final bool sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) {
      return '${formatShortDate(start)}, ${formatClock(start)} às ${formatClock(end)}';
    }
    return '${formatShortDate(start)} ${formatClock(start)} até '
        '${formatShortDate(end)} ${formatClock(end)}';
  }
  final String days = capitalizeFirst(describeDays(period.days));
  final String suffix = period.crossesMidnight ? ' do dia seguinte' : '';
  return '$days, ${period.start} às ${period.end}$suffix';
}

/// Resumo dos periodos de bloqueio para a visao geral das regras.
String blockPeriodsSummary(List<BlockPeriod> periods) {
  if (periods.isEmpty) {
    return 'Nenhum período';
  }
  final List<BlockPeriod> active = periods.where((BlockPeriod period) => period.enabled).toList();
  final int inactive = periods.length - active.length;
  if (active.isEmpty) {
    return '$inactive ${inactive == 1 ? 'período desativado' : 'períodos desativados'}';
  }
  final String head = active.length == 1
      ? '1 ativo: ${active.single.label.isEmpty ? 'sem nome' : active.single.label}'
      : '${active.length} ativos';
  return inactive == 0 ? head : '$head, $inactive ${inactive == 1 ? 'desativado' : 'desativados'}';
}
