import 'package:material_ui/material_ui.dart';

import '../../../child_device/domain/entities/child_device.dart';
import '../../domain/entities/policy.dart';

/// Resume em texto o que um grupo de regras define para o aparelho.
typedef RuleGroupSummary = String Function(Policy policy, ChildDevice device);

/// Um grupo de regras na visao geral: icone, titulo, pagina de edicao e o resumo do que vale.
///
/// Cada funcionalidade de regras (tempo de tela, horarios, apps, bloqueio) descreve os seus
/// grupos, e a composicao do app entrega a lista a visao geral (padrao Strategy). Assim a
/// visao geral nao depende das funcionalidades que resume.
final class RuleGroup {
  const RuleGroup({
    required this.icon,
    required this.title,
    required this.path,
    required this.summarize,
  });

  final IconData icon;
  final String title;

  /// Caminho da pagina de edicao do grupo.
  final String path;
  final RuleGroupSummary summarize;
}
