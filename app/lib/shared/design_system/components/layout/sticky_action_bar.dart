import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/elevation.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Barra fixa no rodape da pagina com a acao principal (por exemplo, "Salvar regras").
///
/// A acao fica sempre a vista, inclusive em formularios longos, e [message] diz o que vai
/// acontecer ("As mudancas sao enviadas ao aparelho de Joao").
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({required this.child, this.message, super.key});

  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: AppElevation.raised(context.colors),
        border: Border(
          top: BorderSide(color: context.colors.hairline, width: AppSizes.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.md,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (message != null) ...<Widget>[
                  Text(message!, style: context.text.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
