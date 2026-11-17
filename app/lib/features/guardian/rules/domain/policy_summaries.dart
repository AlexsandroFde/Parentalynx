import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../devices/domain/device.dart';
import 'allowed_hours_editing.dart';

/// Resumos em texto de cada grupo de regras, para a visao geral. Funcoes puras.

/// Descreve um conjunto de dias da semana: `todos os dias`, `seg a sex`, `sáb e dom`,
/// `seg, qua e sex`.
String describeDays(Iterable<int> days) {
  final List<int> sorted = days.toSet().toList()..sort();
  if (sorted.isEmpty) {
    return 'nenhum dia';
  }
  if (sorted.length == 7) {
    return 'todos os dias';
  }
  final bool consecutive = sorted.last - sorted.first == sorted.length - 1;
  if (consecutive && sorted.length >= 3) {
    return '${weekdayShort(sorted.first)} a ${weekdayShort(sorted.last)}';
  }
  final List<String> names = sorted.map(weekdayShort).toList();
  if (names.length == 1) {
    return names.single;
  }
  return '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
}

String _capitalize(String text) {
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

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
  final String days = _capitalize(describeDays(period.days));
  final String suffix = period.crossesMidnight ? ' do dia seguinte' : '';
  return '$days, ${period.start} às ${period.end}$suffix';
}

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

String appsSummary(AppsPolicy apps) {
  final int blocked = apps.blockedCount;
  final int exceptions = apps.exceptionCount;
  final int withLimit = apps.rules.values
      .where((AppRule rule) => rule.dailyLimitMinutes != null)
      .length;
  final List<String> parts = <String>[
    if (blocked > 0) '$blocked ${blocked == 1 ? 'bloqueado' : 'bloqueados'}',
    if (exceptions > 0) '$exceptions ${exceptions == 1 ? 'exceção' : 'exceções'}',
    if (withLimit > 0) '$withLimit com limite próprio',
  ];
  final String rules = parts.isEmpty ? 'Nenhuma regra por app' : parts.join(', ');
  return apps.defaultForNewApps == NewAppDefault.blocked
      ? '$rules. Apps novos aguardam aprovação'
      : rules;
}

String exceptionsSummary(AppsPolicy apps) {
  final int exceptions = apps.exceptionCount;
  if (exceptions == 0) {
    return 'Emergência e funções do sistema sempre disponíveis';
  }
  return 'Emergência, sistema e $exceptions '
      '${exceptions == 1 ? 'app liberado' : 'apps liberados'}';
}

String webSummary(WebPolicy web) {
  if (!web.managedBrowser) {
    return 'Navegador gerenciado desligado';
  }
  if (web.mode == WebMode.allowlist) {
    final int count = web.allowedDomains.length;
    return 'Só sites autorizados ($count)';
  }
  final int categories = web.blockedCategories.length;
  final int domains = web.blockedDomains.length;
  final List<String> parts = <String>[
    if (categories > 0) '$categories ${categories == 1 ? 'categoria' : 'categorias'}',
    if (domains > 0) '$domains ${domains == 1 ? 'site' : 'sites'}',
    if (web.safeDns) 'filtro familiar',
  ];
  return parts.isEmpty ? 'Navegador gerenciado sem filtros' : 'Bloqueia: ${parts.join(', ')}';
}

String protectionSummary(ProtectionPolicy protection, DeviceManagementMode mode) {
  final String tamper = protection.lockOnTamper
      ? 'Bloqueia se a proteção for desativada'
      : 'Só avisa se a proteção for desativada';
  if (mode != DeviceManagementMode.deviceOwner) {
    return tamper;
  }
  final int active = <bool>[
    protection.blockUninstall,
    protection.blockSafeBoot,
    protection.blockFactoryReset,
    protection.blockDateTimeChange,
    protection.blockAddUser,
    protection.blockUnknownSources,
    protection.blockUsbDebugging,
  ].where((bool value) => value).length;
  return '$tamper. $active de 7 travas do sistema ativas';
}
