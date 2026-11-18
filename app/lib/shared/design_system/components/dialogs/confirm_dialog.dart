import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';
import '../buttons/app_button.dart';
import '../cards/app_list_group.dart';

/// Pede confirmacao antes de uma acao importante. Devolve verdadeiro se confirmada.
///
/// [message] explica o que vai acontecer; [consequence] destaca o que nao volta atras
/// ("Esta acao nao pode ser desfeita") ou como desfazer ("Voce pode vincular de novo depois").
/// Com [destructive] o botao de confirmar fica vermelho e o rotulo deve nomear a acao
/// ("Desvincular", nao "OK").
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
  String? consequence,
  IconData? icon,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      consequence: consequence,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.consequence,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? consequence;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Tone tone = destructive ? Tone.danger : Tone.neutral;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconMedallion(
                  icon: icon ?? (destructive ? AppIcons.warning : AppIcons.help),
                  tone: tone,
                  size: AppSizes.avatarLg - AppSpacing.sm,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(header: true, child: Text(title, style: context.text.headlineSmall)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
              ),
              if (consequence != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  consequence!,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: destructive ? context.colors.danger : context.colors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (destructive)
                AppButton.danger(
                  label: confirmLabel,
                  expand: true,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop(true);
                  },
                )
              else
                AppButton.primary(
                  label: confirmLabel,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.tertiary(
                label: cancelLabel,
                expand: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
