import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/feedback_views.dart';

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
