import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/feedback_views.dart';
import '../agent/data/child_agent_repository.dart';
import 'no_retry.dart';

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

/// Etiqueta permanente de que o controle parental esta ativo neste aparelho.
class ActiveControlPill extends StatelessWidget {
  const ActiveControlPill({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusPill(
      label: 'Controle parental ativo',
      tone: Tone.info,
      icon: Icons.shield_outlined,
    );
  }
}

/// Icone de um app instalado, em PNG, buscado uma vez por sessao no lado nativo.
final appIconProvider = FutureProvider.family<Uint8List?, String>((
  Ref ref,
  String packageName,
) async {
  try {
    return await ref.watch(childAgentRepositoryProvider).appIcon(packageName);
  } on AppFailure {
    return null;
  }
}, retry: noRetry);

/// Mostra o icone de um app, com um icone generico enquanto carrega ou quando nao ha.
class NativeAppIcon extends ConsumerWidget {
  const NativeAppIcon({required this.packageName, this.size = 40, super.key});

  final String packageName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Uint8List? bytes = ref.watch(appIconProvider(packageName)).value;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(size * 0.24);
    if (bytes == null || bytes.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: radius),
        child: Icon(Icons.apps_rounded, size: size * 0.56, color: scheme.onSurfaceVariant),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return Container(
            width: size,
            height: size,
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.apps_rounded, size: size * 0.56, color: scheme.onSurfaceVariant),
          );
        },
      ),
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
