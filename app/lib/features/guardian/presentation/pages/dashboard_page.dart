import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../../child_device/presentation/widgets/device_selector.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../domain/entities/active_commands.dart';
import '../../domain/entities/device_connection.dart';
import '../bloc/dashboard/guardian_dashboard_bloc.dart';
import '../texts/dashboard_texts.dart';
import '../widgets/dashboard/dashboard_device_header.dart';
import '../widgets/dashboard/dashboard_lock_banner.dart';
import '../widgets/dashboard/dashboard_protection_card.dart';
import '../widgets/dashboard/dashboard_quick_actions.dart';
import '../widgets/dashboard/dashboard_recent_alerts.dart';
import '../widgets/dashboard/dashboard_time_card.dart';
import '../widgets/dashboard/dashboard_top_apps.dart';

/// Painel do responsavel: estado do aparelho em foco, tempo de hoje e acoes rapidas.
///
/// Usa o [DevicesBloc] do painel (lista e aparelho em foco) e um [GuardianDashboardBloc]
/// acima na arvore, a quem avisa qual aparelho esta em foco.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    _focus(context.read<DevicesBloc>().state.selected);
  }

  void _focus(ChildDevice? device) {
    if (device != null) {
      context.read<GuardianDashboardBloc>().add(DashboardDeviceSelected(device.id));
    }
  }

  Future<void> _refresh() async {
    final Completer<void> devices = Completer<void>();
    final Completer<void> dashboard = Completer<void>();
    context.read<DevicesBloc>().add(DevicesRefreshRequested(completer: devices));
    context.read<GuardianDashboardBloc>().add(DashboardRefreshRequested(completer: dashboard));
    await Future.wait(<Future<void>>[devices.future, dashboard.future]);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<Object?, Object?>>[
        BlocListener<DevicesBloc, DevicesState>(
          listenWhen: (DevicesState previous, DevicesState current) {
            return previous.selected?.id != current.selected?.id;
          },
          listener: (BuildContext context, DevicesState state) => _focus(state.selected),
        ),
        BlocListener<GuardianDashboardBloc, GuardianDashboardState>(
          listenWhen: (GuardianDashboardState previous, GuardianDashboardState current) {
            return previous.command != current.command;
          },
          listener: (BuildContext context, GuardianDashboardState state) {
            switch (state.command) {
              case ActionSucceeded(:final String? message) when message != null:
                showAppSnackBar(context, message, tone: Tone.success);
              case ActionFailed(:final failure):
                showFailure(context, failure);
              default:
                break;
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Início')),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final DevicesState devices = context.watch<DevicesBloc>().state;
    final ChildDevice? selected = devices.selected;
    switch (devices) {
      case DevicesInitial() || DevicesLoading():
        return const LoadingView(message: 'Carregando os aparelhos');
      case DevicesError(:final failure):
        return FailureView(
          error: failure,
          onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
        );
      case DevicesEmpty() || DevicesLoaded():
        if (selected == null) {
          return _NoDevice(pending: devices.pending.length);
        }
    }
    return BlocBuilder<GuardianDashboardBloc, GuardianDashboardState>(
      builder: (BuildContext context, GuardianDashboardState dashboard) {
        if (!dashboard.isShowing(selected.id)) {
          return const LoadingView(message: 'Carregando os aparelhos');
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: _DeviceDashboard(state: dashboard),
        );
      },
    );
  }
}

class _NoDevice extends StatelessWidget {
  const _NoDevice({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    if (pending > 0) {
      return EmptyState(
        icon: Icons.phonelink_ring_outlined,
        title: 'Um aparelho aguarda a sua aprovação',
        message: 'Confira o número de confirmação mostrado nos dois aparelhos e aprove o vínculo.',
        actionLabel: 'Ver pedido de vínculo',
        onAction: () => context.push(GuardianPaths.pairing),
      );
    }
    return EmptyState(
      icon: Icons.phonelink_setup_outlined,
      title: 'Nenhum aparelho vinculado',
      message:
          'Instale o ParentaLynx no aparelho da criança, escolha "Este é o aparelho da '
          'criança" e use o código de vinculação gerado aqui.',
      actionLabel: 'Vincular aparelho',
      onAction: () => context.push(GuardianPaths.pairing),
    );
  }
}

class _DeviceDashboard extends StatelessWidget {
  const _DeviceDashboard({required this.state});

  final GuardianDashboardState state;

  @override
  Widget build(BuildContext context) {
    final ChildDevice device = state.device!;
    final DeviceSnapshot? snapshot = device.snapshot;
    final ActiveCommands commands = state.commands;
    final Suspension? suspension = commands.suspension;
    final DateTime now = context.read<Clock>().now();
    final GuardianDashboardBloc bloc = context.read<GuardianDashboardBloc>();

    return PageBody(
      children: <Widget>[
        const DeviceSelector(),
        DashboardDeviceHeader(
          device: device,
          connection: state.connection ?? DeviceConnection.online,
          now: now,
        ),
        const SizedBox(height: AppSpacing.md),
        DashboardTimeCard(usage: state.usage, now: now),
        if (snapshot != null && (snapshot.lockState.isLocked || commands.paused)) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          DashboardLockBanner(
            snapshot: snapshot,
            paused: commands.paused,
            now: now,
            onResume: () => bloc.add(const DashboardResumeRequested()),
          ),
        ],
        if (suspension != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          NoticeBanner(
            icon: Icons.pause_circle_outline,
            title: 'Regras suspensas até ${formatClockMs(suspension.until)}',
            message:
                'Suspenso: ${suspension.scopes.map((SuspensionScope s) => s.label.toLowerCase()).join(', ')}.',
            actionLabel: 'Encerrar suspensão',
            onAction: () => bloc.add(const DashboardSuspensionEndRequested()),
          ),
        ],
        if (device.pendingTimeRequests > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          NoticeBanner(
            tone: Tone.warning,
            icon: Icons.more_time,
            title: device.pendingTimeRequests == 1
                ? '${device.displayName} pediu mais tempo'
                : '${device.displayName} fez ${device.pendingTimeRequests} pedidos de tempo',
            message: 'Responda para a criança saber se pode continuar.',
            actionLabel: 'Ver pedidos',
            onAction: () => context.go(GuardianPaths.alerts),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        DashboardQuickActions(device: device, commands: commands),
        if (snapshot != null) ..._issueBanners(snapshot),
        const SizedBox(height: AppSpacing.md),
        DashboardTopApps(apps: state.apps),
        const SizedBox(height: AppSpacing.md),
        DashboardRecentAlerts(alerts: state.recentAlerts, now: now),
        const SizedBox(height: AppSpacing.md),
        DashboardProtectionCard(device: device),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  List<Widget> _issueBanners(DeviceSnapshot snapshot) {
    return <Widget>[
      if (!snapshot.enforcementActive) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        const NoticeBanner(
          tone: Tone.danger,
          title: 'Controle inativo no aparelho',
          message: 'O aparelho informou que as regras não estão sendo aplicadas.',
        ),
      ],
      for (final String issue in snapshot.issues) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        NoticeBanner(
          tone: Tone.warning,
          title: describeIssue(issue).title,
          message: describeIssue(issue).message,
        ),
      ],
    ];
  }
}
