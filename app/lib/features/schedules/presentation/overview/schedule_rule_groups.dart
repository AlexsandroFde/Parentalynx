import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/schedule_texts.dart';

/// Grupos de regras de horario na visao geral.
const List<RuleGroup> scheduleRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: Icons.schedule,
    title: 'Horários permitidos',
    path: RulesPaths.hours,
    summarize: _allowedHours,
  ),
  RuleGroup(
    icon: Icons.event_busy_outlined,
    title: 'Períodos de bloqueio',
    path: RulesPaths.periods,
    summarize: _blockPeriods,
  ),
];

String _allowedHours(Policy policy, ChildDevice device) {
  return allowedHoursSummary(policy.allowedHours);
}

String _blockPeriods(Policy policy, ChildDevice device) {
  return blockPeriodsSummary(policy.blockPeriods);
}
