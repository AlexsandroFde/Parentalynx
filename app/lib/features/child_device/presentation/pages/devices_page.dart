import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/child_device.dart';
import '../bloc/devices/devices_bloc.dart';
import '../texts/device_texts.dart';

/// Lista dos aparelhos da conta: ativos, aguardando aprovacao e revogados.
///
/// Usa o [DevicesBloc] do painel.
class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  Future<void> _refresh(BuildContext context) {
    final Completer<void> completer = Completer<void>();
    context.read<DevicesBloc>().add(DevicesRefreshRequested(completer: completer));
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final DevicesState state = context.watch<DevicesBloc>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Aparelhos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(GuardianPaths.pairing),
        icon: const Icon(Icons.add_link),
        label: const Text('Vincular aparelho'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: switch (state) {
          DevicesLoaded(:final List<ChildDevice> devices) => _DevicesList(devices: devices),
          DevicesEmpty() => const _DevicesList(devices: <ChildDevice>[]),
          DevicesError(:final failure) => FailureView(
            error: failure,
            onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
          ),
          DevicesInitial() || DevicesLoading() => const LoadingView(),
        },
      ),
    );
  }
}

class _DevicesList extends StatelessWidget {
  const _DevicesList({required this.devices});

  final List<ChildDevice> devices;

  List<ChildDevice> _with(DeviceLinkStatus status) {
    return devices.where((ChildDevice device) => device.status == status).toList();
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
    final List<ChildDevice> pending = _with(DeviceLinkStatus.pending);
    final List<ChildDevice> active = _with(DeviceLinkStatus.active);
    final List<ChildDevice> revoked = _with(DeviceLinkStatus.revoked);
    final DateTime now = context.read<Clock>().now();
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
          for (final ChildDevice device in active) _DeviceCard(device: device, now: now),
        ],
        if (revoked.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const _SectionTitle('Vínculo revogado'),
          for (final ChildDevice device in revoked) _DeviceCard(device: device, now: now),
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
  const _DeviceCard({required this.device, required this.now});

  final ChildDevice device;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool revoked = device.status == DeviceLinkStatus.revoked;
    final int? revokedAt = device.revokedAt;
    final ({String label, Tone tone, IconData icon}) connection = connectionStatus(
      device,
      now: now,
    );
    final bool degraded = !revoked && (device.snapshot?.isDegraded ?? false);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(GuardianPaths.device(device.id)),
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
                                  : 'Revogado ${formatRelativeMs(revokedAt, now: now)}',
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
