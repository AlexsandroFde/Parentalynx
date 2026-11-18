import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/spacing.dart';

/// Titulo grande no topo do conteudo de uma pagina.
///
/// Diz onde a pessoa esta e sobre o que (por exemplo, "Regras de Joao" com o aparelho logo
/// abaixo), para nao depender da memoria de telas anteriores. [eyebrow] e um rotulo curto
/// acima do titulo; [trailing] fica alinhado a direita (um avatar, uma acao).
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.bottomSpacing = AppSpacing.xl,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(eyebrow!.toUpperCase(), style: context.textStyles.eyebrow),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: AppSpacing.md), trailing!],
        ],
      ),
    );
  }
}
