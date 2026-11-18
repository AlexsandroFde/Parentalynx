import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/screen_time_texts.dart';

/// Grupos de regras de tempo de tela na visao geral.
const List<RuleGroup> screenTimeRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: AppIcons.dailyLimit,
    title: 'Limite diário',
    path: RulesPaths.limit,
    summarize: _dailyLimit,
    topic: RuleGroupTopic.time,
    isActive: _dailyLimitOn,
  ),
];

String _dailyLimit(Policy policy, ChildDevice device) => dailyLimitSummary(policy.dailyLimit);

bool _dailyLimitOn(Policy policy, ChildDevice device) => policy.dailyLimit.enabled;
