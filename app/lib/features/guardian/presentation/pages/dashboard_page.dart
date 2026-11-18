import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../../child_device/presentation/widgets/device_selector.dart';
import '../../domain/entities/device_connection.dart';
import '../bloc/dashboard/guardian_dashboard_bloc.dart';
import '../bloc/dashboard/panel_state.dart';
import '../dialogs/dashboard_command_dialogs.dart';
import '../texts/dashboard_texts.dart';
import '../widgets/dashboard/dashboard_device_header.dart';
import '../widgets/dashboard/dashboard_notices.dart';
import '../widgets/dashboard/dashboard_placeholders.dart';
import '../widgets/dashboard/dashboard_protection_section.dart';
import '../widgets/dashboard/dashboard_quick_actions.dart';
import '../widgets/dashboard/dashboard_recent_alerts.dart';
import '../widgets/dashboard/dashboard_time_section.dart';
import '../widgets/dashboard/dashboard_top_apps.dart';

/// Inicio do painel: como esta a crianca agora e quanto tempo falta, o que pede atencao, as
/// acoes rapidas e um resumo do dia.
///
/// Usa o [DevicesBloc] do painel (lista e aparelho em foco) e um [GuardianDashboardBloc]
/// acima na arvore, a quem avisa qual aparelho esta em foco.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  GuardianDashboardBloc get _bloc => context.read<GuardianDashboardBloc>();

  @override
  void initState() {
    super.initState();
    _focus(context.read<DevicesBloc>().state.selected);
  }

  void _focus(ChildDevice? device) {
    if (device != null) {
      _bloc.add(DashboardDeviceSelected(device.id));
    }
  }

  Future<void> _refresh() async {
    final Completer<void> devices = Completer<void>();
    final Completer<void> dashboard = Completer<void>();
    context.read<DevicesBloc>().add(DevicesRefreshRequested(completer: devices));
    _bloc.add(DashboardRefreshRequested(completer: dashboard));
    await Future.wait(<Future<void>>[devices.future, dashboard.future]);
  }

  Future<void> _pause(ChildDevice device) async {
    final PauseChoice? choice = await showPauseSheet(
      context,
      device: device,
      now: context.read<Clock>().now(),
    );
    if (choice != null && mounted) {
      _bloc.add(DashboardPauseRequested(duration: choice.duration));
    }
  }

  Future<void> _suspend(ChildDevice device) async {
    final SuspensionChoice? choice = await showSuspendRulesSheet(
      context,
      device: device,
      now: context.read<Clock>().now(),
    );
    if (choice != null && mounted) {
      _bloc.add(DashboardSuspendRequested(minutes: choice.minutes, scopes: choice.scopes));
    }
  }

  Future<void> _customExtraTime() async {
    final int? minutes = await showCustomExtraTimePicker(context);
    if (minutes != null && mounted) {
      _bloc.add(DashboardExtraTimeRequested(minutes));
    }
  }

  /// Repete o comando que falhou. Pausa e suspensao voltam para a confirmacao, que tem o
  /// prazo escolhido.
  void _retry(DashboardCommand command, ChildDevice device) {
    switch (command.kind) {
      case DashboardCommandKind.extraTime:
        _bloc.add(DashboardExtraTimeRequested(command.minutes ?? 0));
      case DashboardCommandKind.pause:
        unawaited(_pause(device));
      case DashboardCommandKind.resume:
        _bloc.add(const DashboardResumeRequested());
      case DashboardCommandKind.suspend:
        unawaited(_suspend(device));
      case DashboardCommandKind.endSuspension:
        _bloc.add(const DashboardSuspensionEndRequested());
    }
  }

  void _onCommand(BuildContext context, GuardianDashboardState state) {
    switch (state.command) {
      case ActionSucceeded(:final String? message) when message != null:
        showAppSnackBar(context, message, tone: Tone.success);
      case ActionFailed(:final failure):
        final DashboardCommand? command = state.lastCommand;
        final ChildDevice? device = state.device;
        showAppSnackBar(
          context,
          command == null
              ? failure.message
              : '${commandFailureLead(command.kind)} ${failure.message}',
          tone: Tone.danger,
          actionLabel: command == null || device == null ? null : 'Tentar de novo',
          onAction: command == null || device == null ? null : () => _retry(command, device),
        );
      default:
        break;
    }
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
          listener: _onCommand,
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Início'),
          actions: const <Widget>[
            HelpButton(
              title: 'Como usar o painel',
              subtitle: 'O que cada parte do Início mostra e quando as mudanças valem.',
              topics: dashboardHelpTopics,
            ),
          ],
        ),
        body: StateSwitcher(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final DevicesState devices = context.watch<DevicesBloc>().state;
    final ChildDevice? selected = devices.selected;
    switch (devices) {
      case DevicesInitial() || DevicesLoading():
        return const DashboardSkeleton(key: ValueKey<String>('carregando'));
      case DevicesError(:final failure):
        return ErrorState.fromError(
          failure,
          key: const ValueKey<String>('erro'),
          subject: 'os aparelhos',
          onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
        );
      case DevicesEmpty() || DevicesLoaded():
        if (selected == null) {
          return DashboardNoDevice(
            key: const ValueKey<String>('sem-aparelho'),
            pending: devices.pending.length,
            hasInactive:
                devices is DevicesLoaded &&
                devices.devices.any((ChildDevice d) => d.status == DeviceLinkStatus.revoked),
          );
        }
    }
    final GuardianDashboardState dashboard = context.watch<GuardianDashboardBloc>().state;
    if (!dashboard.isShowing(selected.id)) {
      return const DashboardSkeleton(key: ValueKey<String>('carregando'));
    }
    return _DeviceDashboard(
      key: ValueKey<String>('painel-${selected.id}'),
      state: dashboard,
      pendingLinks: devices.pending.length,
      onRefresh: _refresh,
      onPause: _pause,
      onSuspend: _suspend,
      onCustomExtraTime: _customExtraTime,
    );
  }
}

class _DeviceDashboard extends StatelessWidget {
  const _DeviceDashboard({
    required this.state,
    required this.pendingLinks,
    required this.onRefresh,
    required this.onPause,
    required this.onSuspend,
    required this.onCustomExtraTime,
    super.key,
  });

  final GuardianDashboardState state;
  final int pendingLinks;
  final RefreshCallback onRefresh;
  final ValueChanged<ChildDevice> onPause;
  final ValueChanged<ChildDevice> onSuspend;
  final VoidCallback onCustomExtraTime;

  @override
  Widget build(BuildContext context) {
    final ChildDevice device = state.device!;
    final DateTime now = context.read<Clock>().now();
    final GuardianDashboardBloc bloc = context.read<GuardianDashboardBloc>();
    final DashboardCommand? running = state.runningCommand;
    void resume() => bloc.add(const DashboardResumeRequested());
    void endSuspension() => bloc.add(const DashboardSuspensionEndRequested());
    void retryPanels() => bloc.add(const DashboardRefreshRequested());

    return AppPageBody(
      onRefresh: onRefresh,
      children: <Widget>[
        const DeviceSelector(),
        DashboardDeviceHeader(
          device: device,
          connection: state.connection ?? DeviceConnection.online,
          sync: state.policySync ?? device.policySync,
          now: now,
        ),
        DashboardNotices(
          device: device,
          commands: state.commands,
          sync: state.policySync ?? device.policySync,
          pendingLinks: pendingLinks,
          policyLoaded: state.policy is PanelLoaded,
          busy: running != null,
          now: now,
          onResume: resume,
          onEndSuspension: endSuspension,
        ),
        const SectionGap(),
        DashboardTimeSection(
          device: device,
          extraMinutesToday: state.commands.extraMinutesToday,
          running: running,
          now: now,
          onExtraTime: (int minutes) => bloc.add(DashboardExtraTimeRequested(minutes)),
          onCustomExtraTime: onCustomExtraTime,
          onAdjustLimit: () => context.go(RulesPaths.limit),
        ),
        const SectionGap(),
        DashboardQuickActions(
          device: device,
          commands: state.commands,
          running: running,
          onPause: () => onPause(device),
          onResume: resume,
          onSuspend: () => onSuspend(device),
          onEndSuspension: endSuspension,
        ),
        const SectionGap(),
        DashboardTopApps(apps: state.apps, childName: device.displayName, onRetry: retryPanels),
        const SectionGap(),
        DashboardRecentAlerts(alerts: state.recentAlerts, now: now, onRetry: retryPanels),
        const SectionGap(),
        DashboardProtectionSection(device: device),
      ],
    );
  }
}
