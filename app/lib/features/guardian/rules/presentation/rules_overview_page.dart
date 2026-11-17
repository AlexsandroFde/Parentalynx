import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../dashboard/presentation/widgets/device_selector.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../guardian_paths.dart';
import '../domain/policy_summaries.dart';
import '../rules_paths.dart';
import 'policy_editor.dart';
import 'widgets/policy_sync_status.dart';

/// Visao geral das regras do aparelho em foco, com o resumo de cada grupo.
class RulesOverviewPage extends ConsumerWidget {
  const RulesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Device? device = ref.watch(selectedDeviceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Regras')),
      body: device == null ? _NoDevice(ref: ref) : _Overview(device: device),
    );
  }
}

class _NoDevice extends StatelessWidget {
  const _NoDevice({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
    if (devices.isLoading && !devices.hasValue) {
      return const LoadingView();
    }
    if (devices.hasError && !devices.hasValue) {
      return FailureView(
        error: devices.error!,
        onRetry: () => ref.read(devicesProvider.notifier).refresh(),
      );
    }
    return EmptyState(
      icon: Icons.rule_outlined,
      title: 'Nenhum aparelho vinculado',
      message: 'As regras são definidas por aparelho. Vincule o aparelho da criança para começar.',
      actionLabel: 'Vincular aparelho',
      onAction: () => context.push(GuardianPaths.pairing),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PolicyEditorState> value = ref.watch(policyEditorProvider(device.id));
    return AsyncValueView<PolicyEditorState>(
      value: value,
      loadingMessage: 'Carregando as regras',
      onRetry: () => ref.invalidate(policyEditorProvider(device.id)),
      data: (PolicyEditorState state) {
        final Policy policy = state.draft;
        final ThemeData theme = Theme.of(context);
        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(devicesProvider.notifier).refresh();
            if (!state.isDirty) {
              await ref.read(policyEditorProvider(device.id).notifier).reload();
            }
          },
          child: PageBody(
            children: <Widget>[
              const DeviceSelector(),
              Text('Regras de ${device.displayName}', style: theme.textTheme.titleLarge),
              Text(
                device.hardwareLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PolicySyncStatus(device: device),
              const SizedBox(height: AppSpacing.md),
              _GroupTile(
                icon: Icons.timer_outlined,
                title: 'Limite diário',
                summary: dailyLimitSummary(policy.dailyLimit),
                path: RulesPaths.limit,
              ),
              _GroupTile(
                icon: Icons.schedule,
                title: 'Horários permitidos',
                summary: allowedHoursSummary(policy.allowedHours),
                path: RulesPaths.hours,
              ),
              _GroupTile(
                icon: Icons.event_busy_outlined,
                title: 'Períodos de bloqueio',
                summary: blockPeriodsSummary(policy.blockPeriods),
                path: RulesPaths.periods,
              ),
              _GroupTile(
                icon: Icons.apps_outlined,
                title: 'Aplicativos',
                summary: appsSummary(policy.apps),
                path: RulesPaths.apps,
              ),
              _GroupTile(
                icon: Icons.verified_outlined,
                title: 'Exceções e funções essenciais',
                summary: exceptionsSummary(policy.apps),
                path: RulesPaths.exceptions,
              ),
              _GroupTile(
                icon: Icons.public,
                title: 'Navegação na internet',
                summary: webSummary(policy.web),
                path: RulesPaths.web,
              ),
              _GroupTile(
                icon: Icons.gpp_good_outlined,
                title: 'Proteção',
                summary: protectionSummary(policy.protection, device.managementMode),
                path: RulesPaths.protection,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Os horários das regras seguem o fuso do aparelho da criança '
                '(${policy.timezone}).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
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
