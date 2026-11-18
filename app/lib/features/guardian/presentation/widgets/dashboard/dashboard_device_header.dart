import 'package:material_ui/material_ui.dart';

import '../../../../../core/time/formatters.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/feedback_views.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../domain/entities/device_connection.dart';

/// Cabecalho do painel: crianca, aparelho, bateria, conexao e confirmacao das regras.
class DashboardDeviceHeader extends StatelessWidget {
  const DashboardDeviceHeader({
    required this.device,
    required this.connection,
    required this.now,
    super.key,
  });

  final ChildDevice device;
  final DeviceConnection connection;
  final DateTime now;

  StatusPill _connectionPill() {
    final int? lastSync = device.lastSyncAt;
    return switch (connection) {
      DeviceConnection.online => const StatusPill(
        label: 'Online',
        tone: Tone.success,
        icon: Icons.wifi,
      ),
      DeviceConnection.neverSynced => const StatusPill(
        label: 'Nunca sincronizou',
        tone: Tone.warning,
        icon: Icons.cloud_off_outlined,
      ),
      DeviceConnection.recent || DeviceConnection.stale => StatusPill(
        label: 'Visto ${formatRelativeMs(lastSync ?? 0, now: now)}',
        tone: connection == DeviceConnection.stale ? Tone.warning : Tone.neutral,
        icon: Icons.cloud_off_outlined,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? battery = device.snapshot?.batteryPercent;
    final String name = device.displayName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(name, style: theme.textTheme.titleLarge),
                      Text(
                        battery == null
                            ? device.hardwareLabel
                            : '${device.hardwareLabel}. Bateria $battery%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                _connectionPill(),
                if (device.policyPending)
                  const StatusPill(
                    label: 'Aguardando o aparelho confirmar',
                    tone: Tone.info,
                    icon: Icons.sync,
                  )
                else
                  const StatusPill(
                    label: 'Regras aplicadas no aparelho',
                    tone: Tone.success,
                    icon: Icons.check_circle_outline,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
