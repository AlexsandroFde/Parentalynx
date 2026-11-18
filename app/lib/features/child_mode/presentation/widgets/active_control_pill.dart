import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';

/// Etiqueta permanente de que o controle parental esta ativo neste aparelho: o app nunca fica
/// escondido.
class ActiveControlPill extends StatelessWidget {
  const ActiveControlPill({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(
      label: 'Controle parental ativo',
      tone: Tone.info,
      icon: AppIcons.protection,
    );
  }
}
