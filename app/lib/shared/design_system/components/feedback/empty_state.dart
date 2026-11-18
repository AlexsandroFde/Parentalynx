import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';
import '../buttons/app_button.dart';

/// Estado vazio: o que apareceria ali e, quando faz sentido, o proximo passo
/// ("Nenhum aparelho vinculado" + "Vincular aparelho").
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = Tone.neutral,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Tone tone;

  /// Versao menor, para dentro de uma secao (sem centralizar na tela).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double blob = compact ? AppSizes.avatarLg : AppSizes.illustration + AppSpacing.lg;
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: blob,
            height: blob,
            decoration: BoxDecoration(color: tone.background(context), shape: BoxShape.circle),
            child: Icon(icon, size: blob * 0.45, color: tone.foreground(context)),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            title,
            style: compact ? context.text.titleSmall : context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        if (message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
            child: Text(
              message!,
              style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...<Widget>[
          SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
          AppButton.secondary(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        child: content,
      );
    }
    return Center(
      child: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.xxl), child: content),
    );
  }
}
