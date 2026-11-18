import 'package:material_ui/material_ui.dart';

import '../../tokens/spacing.dart';

/// Corpo rolavel de uma pagina: aplica a margem padrao e limita a largura do conteudo em
/// telas largas. Com [onRefresh] a pagina pode ser atualizada puxando para baixo.
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    required this.children,
    this.padding = AppSpacing.page,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.onRefresh,
    this.controller,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final RefreshCallback? onRefresh;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final Widget list = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          controller: controller,
          physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: children,
        ),
      ),
    );
    if (onRefresh == null) {
      return list;
    }
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Espaco vertical entre secoes de uma pagina.
class SectionGap extends StatelessWidget {
  const SectionGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: AppSpacing.sectionGap);
}
