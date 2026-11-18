import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Superficie de conteudo sobre o fundo da pagina: plana, com contorno fino e sem sombra.
///
/// Use para o conteudo de destaque de uma secao (o tempo de hoje, um resumo). Para listas de
/// itens use [AppListGroup]; para avisos, [AppBanner]. Com [tone] o painel ganha o fundo leve
/// e o contorno do tom (por exemplo, um resumo de estado); use com moderacao.
class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    this.padding = AppSpacing.panel,
    this.tone,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Tone? tone;
  final VoidCallback? onTap;

  /// Resumo lido pelo leitor de tela no lugar do conteudo, quando o painel e um bloco so.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color color = tone?.background(context) ?? context.colors.surface;
    final Color border = tone?.border(context) ?? context.colors.hairline;
    final Widget content = Padding(padding: padding, child: child);
    Widget panel = Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: context.shapes.containerRadius,
        side: BorderSide(color: border, width: AppSizes.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    if (semanticLabel != null) {
      panel = Semantics(
        container: true,
        button: onTap != null,
        label: semanticLabel,
        excludeSemantics: true,
        child: panel,
      );
    }
    return panel;
  }
}
