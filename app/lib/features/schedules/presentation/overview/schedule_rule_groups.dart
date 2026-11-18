import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/schedule_texts.dart';

/// Grupos de regras de horario na visao geral.
const List<RuleGroup> scheduleRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: AppIcons.allowedHours,
    title: 'Horários permitidos',
    path: RulesPaths.hours,
    summarize: _allowedHours,
    topic: RuleGroupTopic.time,
    isActive: _allowedHoursOn,
  ),
  RuleGroup(
    icon: AppIcons.bedtime,
    title: 'Períodos de bloqueio',
    path: RulesPaths.periods,
    summarize: _blockPeriods,
    topic: RuleGroupTopic.time,
    tone: Tone.rest,
    isActive: _anyPeriodOn,
  ),
];

String _allowedHours(Policy policy, ChildDevice device) {
  return allowedHoursSummary(policy.allowedHours);
}

bool _allowedHoursOn(Policy policy, ChildDevice device) => policy.allowedHours.enabled;

String _blockPeriods(Policy policy, ChildDevice device) {
  return blockPeriodsSummary(policy.blockPeriods);
}

bool _anyPeriodOn(Policy policy, ChildDevice device) {
  return policy.blockPeriods.any((BlockPeriod period) => period.enabled);
}
