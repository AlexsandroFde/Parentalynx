import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/blocking_texts.dart';

/// Grupos de regras de bloqueio na visao geral.
const List<RuleGroup> blockingRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: Icons.public,
    title: 'Navegação na internet',
    path: RulesPaths.web,
    summarize: _web,
  ),
  RuleGroup(
    icon: Icons.gpp_good_outlined,
    title: 'Proteção',
    path: RulesPaths.protection,
    summarize: _protection,
  ),
];

String _web(Policy policy, ChildDevice device) => webSummary(policy.web);

String _protection(Policy policy, ChildDevice device) {
  return protectionSummary(policy.protection, device.managementMode);
}
