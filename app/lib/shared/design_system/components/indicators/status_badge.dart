import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Indicador curto de estado ("Online", "Bloqueado", "Aguardando resposta"): um marcador na cor
/// do tom e o texto, sem caixa em volta.
///
/// Sempre com texto, nunca so cor. Por padrao o marcador e um ponto; passe [icon] quando um
/// icone especifico ajuda a reconhecer o estado (bateria, conexao), ou [showIcon] falso quando
/// o indicador ja esta ao lado de um icone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.tone = Tone.neutral,
    this.icon,
    this.showIcon = true,
    super.key,
  });

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final Color color = tone.foreground(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showIcon) ...<Widget>[
          if (icon != null)
            Icon(icon, size: AppSizes.iconSm, color: color)
          else
            Container(
              width: AppSizes.statusDot,
              height: AppSizes.statusDot,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          SizedBox(width: icon != null ? AppSpacing.xs + AppSpacing.xxs : AppSpacing.sm),
        ],
        Flexible(
          child: Text(label, style: context.text.labelMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}
