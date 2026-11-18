import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Aviso dentro da pagina: icone, titulo, explicacao e uma acao para resolver.
///
/// Para erros, o texto diz o que aconteceu, o que foi ou nao salvo e o que fazer; a acao leva
/// direto a solucao ("Tentar de novo", "Abrir permissoes"). Com [liveRegion] o leitor de
/// tela anuncia o aviso assim que ele aparece.
class AppBanner extends StatelessWidget {
  const AppBanner({
    required this.message,
    this.title,
    this.tone = Tone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.liveRegion = false,
    super.key,
  });

  final String? title;
  final String message;
  final Tone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final Color onBackground = tone.onBackground(context);
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: Container(
        padding: AppSpacing.panel,
        decoration: BoxDecoration(
          color: tone.background(context),
          borderRadius: context.shapes.containerRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon ?? tone.icon, color: tone.foreground(context), size: AppSizes.iconLg),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null) ...<Widget>[
                    Text(title!, style: context.text.titleSmall?.copyWith(color: onBackground)),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  Text(message, style: context.text.bodyMedium?.copyWith(color: onBackground)),
                  if (actionLabel != null && onAction != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    // A acao alinha com o texto do aviso; a area de toque continua com 48.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: onBackground,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
                          textStyle: context.text.labelLarge?.copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: onBackground,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
