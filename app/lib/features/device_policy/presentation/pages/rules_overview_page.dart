import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../../child_device/presentation/widgets/device_selector.dart';
import '../../../device_sync/presentation/widgets/policy_sync_status_view.dart';
import '../../domain/entities/policy.dart';
import '../bloc/policy_overview/policy_overview_bloc.dart';
import '../overview/rule_group.dart';

/// Aba "Regras": escolhe o aparelho em foco e explica quando nao ha aparelho vinculado.
///
/// O conteudo de um aparelho e montado por [bodyBuilder], que recebe o aparelho e cria o
/// BLoC da visao geral com uma chave pelo identificador (recomeca ao trocar de aparelho).
class RulesOverviewGate extends StatelessWidget {
  const RulesOverviewGate({required this.bodyBuilder, super.key});

  final Widget Function(BuildContext context, ChildDevice device) bodyBuilder;

  @override
  Widget build(BuildContext context) {
    final DevicesState devices = context.watch<DevicesBloc>().state;
    final ChildDevice? device = devices.selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Regras')),
      body: device == null ? _NoDevice(state: devices) : bodyBuilder(context, device),
    );
  }
}

class _NoDevice extends StatelessWidget {
  const _NoDevice({required this.state});

  final DevicesState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      DevicesInitial() || DevicesLoading() => const LoadingView(),
      DevicesError(:final failure) => FailureView(
        error: failure,
        onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
      ),
      DevicesEmpty() || DevicesLoaded() => EmptyState(
        icon: Icons.rule_outlined,
        title: 'Nenhum aparelho vinculado',
        message:
            'As regras são definidas por aparelho. Vincule o aparelho da criança para começar.',
        actionLabel: 'Vincular aparelho',
        onAction: () => context.push(GuardianPaths.pairing),
      ),
    };
  }
}

/// Visao geral das regras de um aparelho, com o resumo de cada grupo.
///
/// Espera um [PolicyOverviewBloc] acima na arvore. Os grupos vem das funcionalidades de
/// regras, na ordem em que devem aparecer.
class RulesOverviewBody extends StatelessWidget {
  const RulesOverviewBody({required this.device, required this.groups, super.key});

  final ChildDevice device;
  final List<RuleGroup> groups;

  Future<void> _refresh(BuildContext context) {
    final Completer<void> done = Completer<void>();
    context.read<PolicyOverviewBloc>().add(PolicyOverviewRefreshRequested(completer: done));
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyOverviewBloc, PolicyOverviewState>(
      builder: (BuildContext context, PolicyOverviewState state) {
        return switch (state) {
          PolicyOverviewLoading() => const LoadingView(message: 'Carregando as regras'),
          PolicyOverviewError(:final failure) => FailureView(
            error: failure,
            onRetry: () => context.read<PolicyOverviewBloc>().add(PolicyOverviewStarted(device.id)),
          ),
          PolicyOverviewLoaded(:final policy) => RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: _Groups(device: device, policy: policy.policy, groups: groups),
          ),
        };
      },
    );
  }
}

class _Groups extends StatelessWidget {
  const _Groups({required this.device, required this.policy, required this.groups});

  final ChildDevice device;
  final Policy policy;
  final List<RuleGroup> groups;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PageBody(
      children: <Widget>[
        const DeviceSelector(),
        Text('Regras de ${device.displayName}', style: theme.textTheme.titleLarge),
        Text(
          device.hardwareLabel,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        PolicySyncStatusView(status: device.policySync),
        const SizedBox(height: AppSpacing.md),
        for (final RuleGroup group in groups)
          _GroupTile(
            icon: group.icon,
            title: group.title,
            summary: group.summarize(policy, device),
            path: group.path,
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Os horários das regras seguem o fuso do aparelho da criança '
          '(${policy.timezone}).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.icon,
    required this.title,
    required this.summary,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String summary;
  final String path;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(path),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
