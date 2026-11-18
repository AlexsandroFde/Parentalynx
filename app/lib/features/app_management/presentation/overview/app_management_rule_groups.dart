import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/overview/rule_group.dart';
import '../texts/app_management_texts.dart';

/// Grupos de regras de aplicativos na visao geral.
const List<RuleGroup> appManagementRuleGroups = <RuleGroup>[
  RuleGroup(
    icon: AppIcons.apps,
    title: 'Aplicativos',
    path: RulesPaths.apps,
    summarize: _apps,
    topic: RuleGroupTopic.apps,
  ),
  RuleGroup(
    icon: AppIcons.exception,
    title: 'Exceções e funções essenciais',
    path: RulesPaths.exceptions,
    summarize: _exceptions,
    topic: RuleGroupTopic.apps,
    tone: Tone.success,
  ),
];

String _apps(Policy policy, ChildDevice device) => appsSummary(policy.apps);

String _exceptions(Policy policy, ChildDevice device) => exceptionsSummary(policy.apps);
