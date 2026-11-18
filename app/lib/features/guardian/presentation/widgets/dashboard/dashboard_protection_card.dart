import 'package:material_ui/material_ui.dart';

import '../../../../../shared/widgets/feedback_views.dart';
import '../../../../../shared/widgets/form_widgets.dart';
import '../../../../blocking/presentation/texts/blocking_texts.dart' show guaranteesOf;
import '../../../../child_device/domain/entities/child_device.dart';

/// Nivel de protecao do aparelho: o que o modo de gerenciamento garante ou nao.
class DashboardProtectionCard extends StatelessWidget {
  const DashboardProtectionCard({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DeviceManagementMode mode = device.managementMode;
    final ({List<String> guaranteed, List<String> notGuaranteed}) info = guaranteesOf(mode);
    return SectionCard(
      title: 'Nível de proteção',
      subtitle: 'Modo: ${mode.label}',
      trailing: mode.isSystemEnforced
          ? const StatusPill(
              label: 'Garantido pelo sistema',
              tone: Tone.success,
              icon: Icons.verified_user_outlined,
            )
          : const StatusPill(
              label: 'Não garantido',
              tone: Tone.warning,
              icon: Icons.report_gmailerrorred,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String item in mode.isSystemEnforced ? info.guaranteed : info.notGuaranteed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item', style: theme.textTheme.bodyMedium),
            ),
          if (!mode.isSystemEnforced)
            Text(
              'Tudo o que depende de permissões que a criança pode desativar é avisado a você '
              'por alerta, mas não pode ser impedido neste modo.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
