import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/child_device.dart';
import '../bloc/devices/devices_bloc.dart';
import '../texts/device_texts.dart';

/// Aparelhos da conta: ativos (com a conexao e a protecao de cada um), pedidos aguardando
/// aprovacao e desvinculados.
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
    void link() => context.push(GuardianPaths.pairing);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aparelhos'),
        actions: <Widget>[
          AppIconButton(icon: AppIcons.addLink, tooltip: 'Vincular aparelho', onPressed: link),
        ],
      ),
      body: StateSwitcher(
        child: switch (state) {
          DevicesLoaded(:final List<ChildDevice> devices) => _DevicesList(
            key: const ValueKey<String>('lista'),
            devices: devices,
            onRefresh: () => _refresh(context),
          ),
          DevicesEmpty() => AppPageBody(
            key: const ValueKey<String>('vazio'),
            onRefresh: () => _refresh(context),
            children: <Widget>[
              const EmptyState(
                compact: true,
                icon: AppIcons.devices,
                title: 'Nenhum aparelho vinculado',
                message:
                    'Gere um código de vinculação e digite no aparelho da criança para começar.',
              ),
              AppButton.primary(
                label: 'Vincular aparelho',
                icon: AppIcons.addLink,
                expand: true,
                onPressed: link,
              ),
            ],
          ),
          DevicesError(:final failure) => ErrorState.fromError(
            failure,
            key: const ValueKey<String>('erro'),
            subject: 'os aparelhos',
            onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
          ),
          DevicesInitial() || DevicesLoading() => const AppPageBody(
            key: ValueKey<String>('carregando'),
            children: <Widget>[SkeletonListGroup()],
          ),
        },
      ),
    );
  }
}

class _DevicesList extends StatelessWidget {
  const _DevicesList({required this.devices, required this.onRefresh, super.key});

  final List<ChildDevice> devices;
  final RefreshCallback onRefresh;

  List<ChildDevice> _with(DeviceLinkStatus status) {
    return devices.where((ChildDevice device) => device.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<ChildDevice> pending = _with(DeviceLinkStatus.pending);
    final List<ChildDevice> active = _with(DeviceLinkStatus.active);
    final List<ChildDevice> revoked = _with(DeviceLinkStatus.revoked);
    final DateTime now = context.read<Clock>().now();
    void open(ChildDevice device) => context.push(GuardianPaths.device(device.id));
    return AppPageBody(
      onRefresh: onRefresh,
      children: <Widget>[
        if (pending.isNotEmpty) ...<Widget>[
          AppBanner(
            icon: AppIcons.deviceRinging,
            title: pending.length == 1
                ? 'Um pedido de vínculo aguarda a sua aprovação'
                : '${pending.length} pedidos de vínculo aguardam a sua aprovação',
            message: 'Confira o número de confirmação nos dois aparelhos e aprove ou rejeite.',
            actionLabel: 'Ver pedidos',
            onAction: () => context.push(GuardianPaths.pairing),
          ),
          const SectionGap(),
        ],
        if (active.isNotEmpty) ...<Widget>[
          AppSection(
            title: 'Ativos',
            child: AppListGroup(
              dividerIndent: AppSpacing.lg + AppSizes.avatarMd + AppSpacing.md,
              children: <Widget>[
                for (final ChildDevice device in active)
                  _ActiveRow(device: device, now: now, onTap: () => open(device)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.secondary(
            label: active.isEmpty ? 'Vincular aparelho' : 'Vincular outro aparelho',
            icon: AppIcons.addLink,
            onPressed: () => context.push(GuardianPaths.pairing),
          ),
        ),
        if (revoked.isNotEmpty) ...<Widget>[
          const SectionGap(),
          AppSection(
            title: 'Desvinculados',
            subtitle: 'Não são mais controlados. O histórico fica guardado até você apagar.',
            child: AppListGroup(
              children: <Widget>[
                for (final ChildDevice device in revoked)
                  AppListRow(
                    leading: const AppIconTile(icon: AppIcons.unlink, tone: Tone.neutral),
                    title: device.displayName,
                    subtitle: device.revokedAt == null
                        ? device.hardwareLabel
                        : 'Desvinculado ${formatRelativeMs(device.revokedAt!, now: now)}',
                    onTap: () => open(device),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({required this.device, required this.now, required this.onTap});

  final ChildDevice device;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ({String label, Tone tone, IconData icon}) connection = connectionStatus(
      device,
      now: now,
    );
    final bool degraded = device.snapshot?.isDegraded ?? false;
    return AppListRow(
      leading: InitialAvatar(name: device.displayName),
      title: device.displayName,
      subtitle: device.hardwareLabel,
      below: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          StatusBadge(label: connection.label, tone: connection.tone, icon: connection.icon),
          if (degraded)
            const StatusBadge(
              label: 'Proteção incompleta',
              tone: Tone.warning,
              icon: AppIcons.protectionWeak,
            ),
          if (device.policyPending)
            const StatusBadge(label: 'Regras aguardando o aparelho', tone: Tone.warning),
        ],
      ),
      onTap: onTap,
    );
  }
}
