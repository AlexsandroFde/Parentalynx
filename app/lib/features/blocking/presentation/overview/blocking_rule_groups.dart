import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/blocking_texts.dart';

/// Grupos de regras de bloqueio na visao geral.
const List<RuleGroup> blockingRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: AppIcons.web,
    title: 'Navegação na internet',
    path: RulesPaths.web,
    summarize: _web,
    topic: RuleGroupTopic.safety,
    isActive: _browserOn,
  ),
  RuleGroup(
    icon: AppIcons.protection,
    title: 'Proteção',
    path: RulesPaths.protection,
    summarize: _protection,
    topic: RuleGroupTopic.safety,
  ),
];

String _web(Policy policy, ChildDevice device) => webSummary(policy.web);

bool _browserOn(Policy policy, ChildDevice device) => policy.web.managedBrowser;

String _protection(Policy policy, ChildDevice device) {
  return protectionSummary(policy.protection, device.managementMode);
}
