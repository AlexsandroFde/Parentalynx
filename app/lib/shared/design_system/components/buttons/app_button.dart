import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/colors.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Hierarquia do botao. Cada tela tem no maximo um [primary] visivel por vez.
enum AppButtonVariant {
  /// A acao principal da tela ("Salvar", "Criar conta").
  primary,

  /// Acoes de apoio com o mesmo peso entre si ("+ 15 min", "Ver relatorio").
  secondary,

  /// Acoes discretas e links ("Cancelar", "Ver todos").
  tertiary,

  /// Acoes destrutivas ou que retiram acesso ("Desvincular", "Excluir conta").
  danger,
}

enum AppButtonSize {
  /// Altura de 52: botoes de formulario e de pagina.
  regular,

  /// Altura visual de 40 (area de toque de 48): botoes dentro de linhas e paineis.
  compact,
}

/// Botao do Design System.
///
/// Enquanto [busy] e verdadeiro o botao mostra um indicador ao lado do rotulo e ignora
/// toques, sem parecer desabilitado (o que confundiria "ocupado" com "indisponivel"). Isso
/// evita o envio duplicado de uma operacao. Rotulos longos quebram em duas linhas em vez de
/// serem cortados, para funcionar com fonte ampliada.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.size = AppButtonSize.regular,
    super.key,
  });

  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.size = AppButtonSize.regular,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.size = AppButtonSize.regular,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.tertiary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.size = AppButtonSize.regular,
    super.key,
  }) : variant = AppButtonVariant.tertiary;

  const AppButton.danger({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.size = AppButtonSize.regular,
    super.key,
  }) : variant = AppButtonVariant.danger;

  final String label;

  /// Nulo deixa o botao desabilitado.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool busy;

  /// Ocupa toda a largura disponivel.
  final bool expand;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color busyColor = switch (variant) {
      AppButtonVariant.primary => c.onPrimary,
      AppButtonVariant.secondary => c.onPrimaryContainer,
      AppButtonVariant.tertiary => c.primary,
      AppButtonVariant.danger => c.onDanger,
    };
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (busy)
          SizedBox.square(
            dimension: AppSizes.iconMd - 2,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: busyColor),
          )
        else if (icon != null)
          Icon(icon, size: AppSizes.iconMd),
        if (busy || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final ButtonStyle? compactStyle = size == AppButtonSize.compact
        ? const ButtonStyle(
            minimumSize: WidgetStatePropertyAll<Size>(
              Size(AppSizes.minTapTarget, AppSizes.controlCompact),
            ),
            padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
              EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
          )
        : null;

    Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        style: compactStyle,
        child: content,
      ),
      AppButtonVariant.secondary => FilledButton.tonal(
        onPressed: onPressed,
        style: compactStyle,
        child: content,
      ),
      AppButtonVariant.tertiary => TextButton(
        onPressed: onPressed,
        style: compactStyle,
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.danger,
          foregroundColor: c.onDanger,
        ).merge(compactStyle),
        child: content,
      ),
    };

    if (busy) {
      button = Semantics(
        label: '$label, em andamento',
        button: true,
        enabled: false,
        excludeSemantics: true,
        child: IgnorePointer(child: button),
      );
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
