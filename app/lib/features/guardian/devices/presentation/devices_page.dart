import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../guardian_paths.dart';
import '../domain/device.dart';
import 'device_texts.dart';
import 'devices_providers.dart';

/// Lista dos aparelhos da conta: ativos, aguardando aprovacao e revogados.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Aparelhos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(GuardianPaths.pairing),
        icon: const Icon(Icons.add_link),
        label: const Text('Vincular aparelho'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(devicesProvider.notifier).refresh(),
        child: AsyncValueView<List<Device>>(
          value: devices,
          onRetry: () => ref.invalidate(devicesProvider),
          data: (List<Device> all) => _DevicesList(devices: all),
        ),
      ),
    );
  }
}

class _DevicesList extends StatelessWidget {
  const _DevicesList({required this.devices});

  final List<Device> devices;

  List<Device> _with(DeviceStatus status) {
    return devices.where((Device device) => device.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: 440,
            child: EmptyState(
              icon: Icons.devices_other_outlined,
              title: 'Nenhum aparelho vinculado',
              message: 'Gere um código de vinculação e digite no aparelho da criança para começar.',
              actionLabel: 'Vincular aparelho',
              onAction: () => context.push(GuardianPaths.pairing),
            ),
          ),
        ],
      );
    }
    final List<Device> pending = _with(DeviceStatus.pending);
    final List<Device> active = _with(DeviceStatus.active);
    final List<Device> revoked = _with(DeviceStatus.revoked);
    return PageBody(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: <Widget>[
        if (pending.isNotEmpty) ...<Widget>[
          NoticeBanner(
            icon: Icons.phonelink_ring_outlined,
            title: pending.length == 1
                ? '1 pedido de vínculo aguardando'
                : '${pending.length} pedidos de vínculo aguardando',
            message: 'Confira o número de confirmação e aprove ou rejeite.',
            actionLabel: 'Ver pedidos',
            onAction: () => context.push(GuardianPaths.pairing),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (active.isNotEmpty) ...<Widget>[
          const _SectionTitle('Ativos'),
          for (final Device device in active) _DeviceCard(device: device),
        ],
        if (revoked.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const _SectionTitle('Vínculo revogado'),
          for (final Device device in revoked) _DeviceCard(device: device),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool revoked = device.status == DeviceStatus.revoked;
    final int? revokedAt = device.revokedAt;
    final ({String label, Tone tone, IconData icon}) connection = connectionStatus(device);
    final bool degraded = !revoked && (device.state?.isDegraded ?? false);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('${GuardianPaths.devices}/${Uri.encodeComponent(device.id)}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: revoked
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    revoked ? Icons.link_off : Icons.smartphone_outlined,
                    color: revoked
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(device.displayName, style: theme.textTheme.titleMedium),
                      Text(
                        device.hardwareLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          if (revoked)
                            StatusPill(
                              label: revokedAt == null
                                  ? 'Revogado'
                                  : 'Revogado ${formatRelativeMs(revokedAt)}',
                              icon: Icons.link_off,
                            )
                          else ...<Widget>[
                            StatusPill(
                              label: connection.label,
                              tone: connection.tone,
                              icon: connection.icon,
                            ),
                            StatusPill(
                              label: device.managementMode.label,
                              icon: device.managementMode.isSystemEnforced
                                  ? Icons.verified_user_outlined
                                  : Icons.shield_outlined,
                            ),
                            if (degraded)
                              const StatusPill(
                                label: 'Proteção incompleta',
                                tone: Tone.warning,
                                icon: Icons.warning_amber_rounded,
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
