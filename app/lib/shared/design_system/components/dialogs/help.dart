import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import '../../foundations/ds_context.dart';
import '../../tokens/spacing.dart';
import 'app_sheet.dart';

/// Um assunto de ajuda: pergunta curta e resposta em linguagem simples.
@immutable
class HelpTopic {
  const HelpTopic({required this.title, required this.body});

  final String title;
  final String body;
}

/// Mostra a ajuda de uma tela ou configuracao em uma folha inferior.
Future<void> showHelpSheet(
  BuildContext context, {
  required String title,
  required List<HelpTopic> topics,
  String? subtitle,
}) {
  return showAppSheet<void>(
    context,
    title: title,
    subtitle: subtitle,
    builder: (BuildContext context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < topics.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            Semantics(header: true, child: Text(topics[i].title, style: context.text.titleSmall)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              topics[i].body,
              style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ],
      );
    },
  );
}

/// Botao de ajuda contextual (icone "?") que abre [showHelpSheet]. Fica ao lado do que
/// precisa de explicacao, para a ajuda aparecer na hora em que e util.
class HelpButton extends StatelessWidget {
  const HelpButton({required this.title, required this.topics, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final List<HelpTopic> topics;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajuda: $title',
      icon: const Icon(AppIcons.help),
      onPressed: () => showHelpSheet(context, title: title, subtitle: subtitle, topics: topics),
    );
  }
}
