import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/screen_time_texts.dart';

/// Grupos de regras de tempo de tela na visao geral.
const List<RuleGroup> screenTimeRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: Icons.timer_outlined,
    title: 'Limite diário',
    path: RulesPaths.limit,
    summarize: _dailyLimit,
  ),
];

String _dailyLimit(Policy policy, ChildDevice device) => dailyLimitSummary(policy.dailyLimit);
