import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';

/// O agente de controle parental deste aparelho nao respondeu.
///
/// Fala com calma (nao e culpa de ninguem), diz o que fazer e oferece tentar de novo. Usado na
/// tela de entrada e na tela inicial.
class ChildProblemView extends StatelessWidget {
  const ChildProblemView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: EmptyState(
        icon: AppIcons.syncProblem,
        tone: Tone.warning,
        title: 'O controle parental não respondeu',
        message:
            'Isso costuma passar sozinho. Toque em "Tentar de novo". Se continuar assim, '
            'reinicie o aparelho.',
        actionLabel: 'Tentar de novo',
        onAction: onRetry,
      ),
    );
  }
}
