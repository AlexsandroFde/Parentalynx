import 'package:material_ui/material_ui.dart';

import '../../../../core/errors/app_failure.dart';
import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Confirmacao curta no rodape da tela ("Limite salvo. O aparelho recebe em instantes.").
///
/// So confirme o que de fato aconteceu: chame depois que a operacao terminar, nunca antes.
/// [actionLabel] oferece um passo seguinte ou "Desfazer", quando possivel.
void showAppSnackBar(
  BuildContext context,
  String message, {
  Tone tone = Tone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  final Color iconColor = context.colors.onInverseSurface;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            if (tone != Tone.neutral) ...<Widget>[
              Icon(tone.icon, color: iconColor, size: AppSizes.iconMd),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

/// Mostra a mensagem de uma falha (o que aconteceu e o que fazer).
void showFailure(BuildContext context, Object error) {
  showAppSnackBar(context, toFailure(error).message, tone: Tone.danger);
}
