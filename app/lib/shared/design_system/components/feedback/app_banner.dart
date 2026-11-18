import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Aviso dentro da pagina: icone, titulo, explicacao e uma acao para resolver.
///
/// Fica sobre a superficie neutra, com contorno fino; o tom aparece no icone e, em atencao e
/// erro, tambem no contorno. Para erros, o texto diz o que aconteceu, o que foi ou nao salvo e
/// o que fazer; a acao leva direto a solucao ("Tentar de novo", "Abrir permissoes"). Com
/// [liveRegion] o leitor de tela anuncia o aviso assim que ele aparece.
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
    final Color messageColor = title == null
        ? context.colors.textPrimary
        : context.colors.textSecondary;
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md + AppSpacing.xxs,
          AppSpacing.lg,
          AppSpacing.md + AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: context.shapes.containerRadius,
          border: Border.all(color: tone.border(context), width: AppSizes.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon ?? tone.icon, color: tone.foreground(context), size: AppSizes.iconMd),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null) ...<Widget>[
                    Text(title!, style: context.text.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  Text(message, style: context.text.bodyMedium?.copyWith(color: messageColor)),
                  if (actionLabel != null && onAction != null)
                    // A acao alinha com o texto do aviso; a area de toque continua com 48.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
                          textStyle: context.text.titleSmall,
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
