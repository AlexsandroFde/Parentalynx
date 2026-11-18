import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/app_management_texts.dart';

/// Grupos de regras de aplicativos na visao geral.
const List<RuleGroup> appManagementRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: Icons.apps_outlined,
    title: 'Aplicativos',
    path: RulesPaths.apps,
    summarize: _apps,
  ),
  RuleGroup(
    icon: Icons.verified_outlined,
    title: 'Exceções e funções essenciais',
    path: RulesPaths.exceptions,
    summarize: _exceptions,
  ),
];

String _apps(Policy policy, ChildDevice device) => appsSummary(policy.apps);

String _exceptions(Policy policy, ChildDevice device) => exceptionsSummary(policy.apps);
