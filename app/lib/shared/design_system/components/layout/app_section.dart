import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/spacing.dart';
import '../buttons/app_button.dart';

/// Secao de uma pagina: titulo, texto de apoio, uma acao opcional a direita ("Ver todos") e o
/// conteudo logo abaixo.
///
/// O titulo fica fora do conteudo, sobre o fundo da pagina; a separacao entre secoes vem do
/// espaco ([AppSpacing.sectionGap]), nao de bordas.
class AppSection extends StatelessWidget {
  const AppSection({
    required this.child,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.spacing = AppSpacing.sectionHeaderGap,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Complemento a direita do titulo no lugar da acao (por exemplo, uma etiqueta de estado).
  final Widget? trailing;
  final Widget child;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final Widget? side =
        trailing ??
        (actionLabel != null && onAction != null
            ? AppButton.tertiary(
                label: actionLabel!,
                onPressed: onAction,
                size: AppButtonSize.compact,
              )
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(header: true, child: Text(title!, style: context.text.titleMedium)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxs),
                          child: Text(
                            subtitle!,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ?side,
            ],
          ),
          SizedBox(height: spacing),
        ],
        child,
      ],
    );
  }
}
