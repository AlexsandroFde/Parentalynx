import 'package:material_ui/material_ui.dart';

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
      AppIconButtonVariant.tonal => IconButton.filledTonal(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
      AppIconButtonVariant.filled => IconButton.filled(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    };
  }
}
