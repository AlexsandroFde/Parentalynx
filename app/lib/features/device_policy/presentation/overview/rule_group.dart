import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../domain/entities/policy.dart';

/// Resume em texto o que um grupo de regras define para o aparelho.
typedef RuleGroupSummary = String Function(Policy policy, ChildDevice device);

/// Diz se a regra do grupo esta ligada (por exemplo, o limite diario desligado).
typedef RuleGroupActive = bool Function(Policy policy, ChildDevice device);

/// Assunto de um grupo na visao geral. Grupos do mesmo assunto aparecem juntos, sob um titulo.
enum RuleGroupTopic {
  time('Tempo e horários'),
  apps('Uso dos aplicativos'),
  safety('Internet e segurança');

  const RuleGroupTopic(this.title);

  final String title;
}

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
    this.topic,
    this.tone = Tone.info,
    this.isActive,
  });

  final IconData icon;
  final String title;

  /// Caminho da pagina de edicao do grupo.
  final String path;
  final RuleGroupSummary summarize;

  /// Assunto do grupo. Grupos sem assunto aparecem no fim, sem titulo.
  final RuleGroupTopic? topic;

  /// Tom do icone quando a regra esta ligada ([Tone.rest] para descanso).
  final Tone tone;

  /// Nulo quando a regra esta sempre valendo. Desligada, o icone fica neutro e o resumo diz
  /// o porque.
  final RuleGroupActive? isActive;
}
