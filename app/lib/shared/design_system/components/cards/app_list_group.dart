import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Lista agrupada: varias linhas em um unico painel, separadas por linhas finas.
///
/// Substitui o "um cartao por item": menos bordas, mais conteudo visivel e uma leitura de
/// cima para baixo. [footer] explica o grupo (regras, consequencias) abaixo dele.
class AppListGroup extends StatelessWidget {
  const AppListGroup({
    required this.children,
    this.footer,
    this.dividerIndent = AppSpacing.lg + AppSizes.iconTile + AppSpacing.md,
    super.key,
  });

  final List<Widget> children;
  final String? footer;

  /// Recuo do divisor: alinha com o texto das linhas que tem icone a esquerda.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: AppSizes.hairline, indent: dividerIndent));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: context.colors.surface,
          borderRadius: context.shapes.containerRadius,
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.none,
            ),
            child: Text(footer!, style: context.text.bodySmall),
          ),
      ],
    );
  }
}

/// Linha de lista: icone ou imagem a esquerda, titulo, texto de apoio e um complemento a
/// direita (valor, etiqueta, chave). Com [onTap] a linha inteira e tocavel e mostra a seta.
///
/// Titulo e texto de apoio quebram linha em vez de serem cortados, para funcionar com fonte
/// ampliada; o leitor de tela le a linha como um item so.
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.below,
    this.onTap,
    this.showChevron,
    this.enabled = true,
    this.titleStyle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Conteudo abaixo do texto, na largura do titulo (por exemplo, a barra de uso de um app).
  final Widget? below;
  final VoidCallback? onTap;

  /// Mostra a seta de navegacao. Por padrao aparece quando a linha e tocavel e nao tem
  /// complemento a direita.
  final bool? showChevron;
  final bool enabled;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final bool chevron = showChevron ?? (onTap != null && trailing == null);
    final Color secondary = context.colors.textSecondary;
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget + AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.row,
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[leading!, const SizedBox(width: AppSpacing.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style:
                        titleStyle ?? context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        subtitle!,
                        style: context.text.bodyMedium?.copyWith(color: secondary),
                      ),
                    ),
                  if (below != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: below,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[const SizedBox(width: AppSpacing.md), trailing!],
            if (chevron) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              Icon(AppIcons.chevronRight, color: secondary, size: AppSizes.iconLg),
            ],
          ],
        ),
      ),
    );
    final Widget row = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: onTap == null ? content : InkWell(onTap: enabled ? onTap : null, child: content),
    );
    return MergeSemantics(child: row);
  }
}

/// Quadrado com icone usado a esquerda das linhas. O tom indica o significado (por exemplo,
/// [Tone.rest] para horarios de descanso).
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    this.tone = Tone.info,
    this.size = AppSizes.iconTile,
    super.key,
  });

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tone.background(context),
          borderRadius: context.shapes.tileRadius,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: size * 0.52, color: tone.foreground(context)),
      ),
    );
  }
}

/// Valor curto a direita de uma linha ("2h 30min", "Ligado").
class AppRowValue extends StatelessWidget {
  const AppRowValue(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.end,
      style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
    );
  }
}
