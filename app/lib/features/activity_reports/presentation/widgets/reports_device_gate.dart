import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../texts/report_texts.dart';

/// Monta uma pagina de detalhe dos relatorios para o aparelho em foco, ou explica por que nao
/// ha aparelho (carregando, falha ou nenhum vinculado).
///
/// O BLoC da pagina deve ser criado dentro de [builder] com uma chave pelo identificador do
/// aparelho, para recomecar quando o aparelho em foco muda.
class ReportsDeviceGate extends StatelessWidget {
  const ReportsDeviceGate({required this.title, required this.builder, super.key});

  /// Titulo da pagina, mostrado tambem quando nao ha aparelho.
  final String title;
  final Widget Function(BuildContext context, ChildDevice device) builder;

  @override
  Widget build(BuildContext context) {
    final DevicesState devices = context.watch<DevicesBloc>().state;
    final ChildDevice? device = devices.selected;
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ReportsNoDevice(devices: devices),
      );
    }
    return builder(context, device);
  }
}

/// Corpo das telas de relatorio sem aparelho em foco.
class ReportsNoDevice extends StatelessWidget {
  const ReportsNoDevice({required this.devices, super.key});

  final DevicesState devices;

  @override
  Widget build(BuildContext context) {
    return StateSwitcher(
      alignment: Alignment.center,
      child: switch (devices) {
        DevicesInitial() || DevicesLoading() => const LoadingState(
          key: ValueKey<String>('carregando'),
          message: 'Carregando os aparelhos',
        ),
        DevicesError(:final failure) => ErrorState.fromError(
          failure,
          key: const ValueKey<String>('erro'),
          subject: 'os aparelhos',
          onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
        ),
        DevicesEmpty() || DevicesLoaded() => EmptyState(
          key: const ValueKey<String>('vazio'),
          icon: AppIcons.devices,
          title: 'Nenhum aparelho vinculado',
          message: 'Os relatórios aparecem depois que o aparelho da criança for vinculado.',
          actionLabel: 'Vincular aparelho',
          onAction: () => context.push(GuardianPaths.pairing),
        ),
      },
    );
  }
}

/// Cabecalho das telas de relatorio: de qual crianca e de qual aparelho sao os dados.
class ReportHeader extends StatelessWidget {
  const ReportHeader({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final String subtitle = device.childName.isNotEmpty && device.deviceName.isNotEmpty
        ? device.deviceName
        : device.hardwareLabel;
    return AppPageHeader(
      title: device.displayName,
      subtitle: subtitle,
      bottomSpacing: AppSpacing.lg,
      trailing: InitialAvatar(name: device.displayName, size: AppSizes.avatarLg),
    );
  }
}

/// De quando sao os dados: a ultima vez que o aparelho enviou o uso ao servidor.
class DeviceFreshnessLine extends StatelessWidget {
  const DeviceFreshnessLine({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final DateTime now = context.read<Clock>().now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          device.online ? AppIcons.synced : AppIcons.offline,
          size: AppSizes.iconSm,
          color: context.colors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            deviceDataFreshness(lastSyncAt: device.lastSyncAt, online: device.online, now: now),
            style: context.text.bodySmall,
          ),
        ),
      ],
    );
  }
}
