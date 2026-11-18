import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/radius.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Etiqueta curta de estado ("Online", "Bloqueado", "Aguardando resposta").
///
/// Sempre com texto e icone, nunca so cor. Por padrao usa o icone do tom; passe [icon] para
/// um mais especifico, ou [showIcon] falso quando a etiqueta ja esta ao lado de um icone.
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
    final Color foreground = tone.foreground(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(icon ?? tone.icon, size: AppSizes.iconSm, color: foreground),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Flexible(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(color: tone.onBackground(context)),
            ),
          ),
        ],
      ),
    );
  }
}
