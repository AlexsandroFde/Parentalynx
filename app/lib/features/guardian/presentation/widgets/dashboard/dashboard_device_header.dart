import 'package:material_ui/material_ui.dart';

import '../../../../../shared/design_system/design_system.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../../child_device/presentation/texts/device_texts.dart';
import '../../../../device_sync/domain/entities/policy_sync_status.dart';
import '../../../../device_sync/presentation/widgets/policy_sync_status_view.dart';
import '../../../domain/entities/device_connection.dart';

/// Cabecalho do painel: de quem e o aparelho, se ele esta conectado, a bateria e se as regras
/// atuais ja valem nele.
class DashboardDeviceHeader extends StatelessWidget {
  const DashboardDeviceHeader({
    required this.device,
    required this.connection,
    required this.sync,
    required this.now,
    super.key,
  });

  final ChildDevice device;
  final DeviceConnection connection;

  /// Confirmacao das regras, contando um comando que o aparelho ainda nao recebeu.
  final PolicySyncStatus sync;
  final DateTime now;

  /// Abaixo deste nivel a bateria merece atencao: o aparelho pode desligar e sair do ar.
  static const int lowBattery = 15;

  @override
  Widget build(BuildContext context) {
    final ({String label, Tone tone, IconData icon}) status = connectionStatus(
      device,
      now: now,
      stale: connection == DeviceConnection.stale,
    );
    final int? battery = device.snapshot?.batteryPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPageHeader(
          eyebrow: 'Hoje',
          title: device.displayName,
          subtitle: device.hardwareLabel,
          trailing: InitialAvatar(name: device.displayName, size: AppSizes.avatarLg),
          bottomSpacing: AppSpacing.md,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            StatusBadge(label: status.label, tone: status.tone, icon: status.icon),
            if (battery != null)
              StatusBadge(
                label: battery <= lowBattery ? 'Bateria fraca: $battery%' : 'Bateria $battery%',
                tone: battery <= lowBattery ? Tone.warning : Tone.neutral,
                icon: AppIcons.battery,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PolicySyncStatusView(status: sync, now: now),
      ],
    );
  }
}
