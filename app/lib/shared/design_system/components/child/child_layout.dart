import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';
import '../cards/app_list_group.dart';

/// Estrutura comum das telas do modo crianca: a tela do codigo e as telas do aparelho
/// vinculado. Dentro de um `AppExperienceScope(experience: AppExperience.child)` tudo fica
/// mais arredondado e com texto maior.

/// Corpo padrao das telas do modo crianca: coluna rolavel, largura limitada em telas largas.
///
/// As telas deste modo sao curtas, entao a coluna e construida inteira (sem lista sob
/// demanda), o que mantem a ordem de leitura previsivel para leitores de tela.
class ChildPageBody extends StatelessWidget {
  const ChildPageBody({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.lg,
      AppSpacing.gutter,
      AppSpacing.xxl,
    ),
    this.controller,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: SingleChildScrollView(
          controller: controller,
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// Cabecalho de tela com um icone em destaque ([IconMedallion]), titulo e texto de apoio.
class ChildHeader extends StatelessWidget {
  const ChildHeader({
    required this.icon,
    required this.title,
    this.message,
    this.tone = Tone.info,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        IconMedallion(icon: icon, tone: tone, size: AppSizes.medallion + AppSpacing.xs),
        const SizedBox(height: AppSpacing.lg),
        Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
        if (message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message!,
            style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Linha de uma explicacao com marcador ("Tempo por dia: 2h 30min").
///
/// O marcador e um icone sem fundo; so os tons de atencao, erro e confirmacao o colorem
/// ([ToneColors.iconColor]).
class BulletLine extends StatelessWidget {
  const BulletLine({
    required this.text,
    required this.icon,
    this.tone = Tone.info,
    this.color,
    super.key,
  });

  final String text;
  final IconData icon;
  final Tone tone;

  /// Cor propria do icone, no lugar da cor do [tone]. Prefira [tone].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(icon, size: AppSizes.iconMd, color: color ?? tone.iconColor(context)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.text.bodyLarge)),
        ],
      ),
    );
  }
}
