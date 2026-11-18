import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';

/// Peso do botao de icone: [standard] sem fundo, [tonal] contornado (acao de apoio ao lado de
/// um conteudo) e [filled] na cor de acao.
enum AppIconButtonVariant { standard, tonal, filled }

/// Botao so com icone. O [tooltip] e obrigatorio: e o nome que o leitor de tela anuncia e a
/// dica que aparece ao segurar o botao.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.standard,
    this.color,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;

  /// Cor do icone na variante padrao.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppIconButtonVariant.standard => IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        color: color,
        onPressed: onPressed,
      ),
      AppIconButtonVariant.tonal => IconButton.outlined(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: context.colors.textPrimary,
          backgroundColor: context.colors.surface,
          side: BorderSide(color: context.colors.border),
          shape: RoundedRectangleBorder(borderRadius: context.shapes.controlRadius),
        ),
      ),
      AppIconButtonVariant.filled => IconButton.filled(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: context.shapes.controlRadius),
        ),
      ),
    };
  }
}
