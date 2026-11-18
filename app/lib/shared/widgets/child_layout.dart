import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Estrutura visual comum das telas do modo crianca: a tela do codigo (aqui) e as telas do
/// aparelho vinculado (`child_mode`), que reaproveitam estes componentes.

/// Corpo padrao das telas do modo crianca: coluna rolavel, largura limitada em telas largas.
///
/// As telas deste modo sao curtas, entao a coluna e construida inteira (sem lista sob
/// demanda), o que mantem a ordem de leitura previsivel para leitores de tela.
class ChildPageBody extends StatelessWidget {
  const ChildPageBody({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 28),
    this.controller,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: SingleChildScrollView(
          controller: controller,
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// Cabecalho de tela com um icone em destaque, titulo e texto de apoio.
class ChildHeader extends StatelessWidget {
  const ChildHeader({required this.icon, required this.title, this.message, super.key});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 30),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
        if (message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message!,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Linha de uma lista de itens com marcador, usada nas explicacoes.
class BulletLine extends StatelessWidget {
  const BulletLine({required this.text, required this.icon, this.color, super.key});

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: color ?? theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
