import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/route_paths.dart';
import '../../../../../core/time/formatters.dart';
import '../../../../../shared/design_system/design_system.dart';
import '../../../../app_management/domain/entities/app_entry.dart';
import '../../../../app_management/presentation/widgets/app_icon_view.dart';
import '../../bloc/dashboard/panel_state.dart';

/// Apps mais usados hoje em uma lista agrupada, com o tempo a direita e uma barra
/// proporcional ao mais usado.
class DashboardTopApps extends StatelessWidget {
  const DashboardTopApps({
    required this.apps,
    required this.childName,
    required this.onRetry,
    super.key,
  });

  final PanelState<DeviceApps> apps;
  final String childName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final List<AppEntry> top = apps.valueOrNull?.topToday() ?? const <AppEntry>[];
    final int maxMs = top.isEmpty ? 1 : top.first.todayMs;
    return AppSection(
      title: 'Mais usados hoje',
      actionLabel: 'Relatórios',
      onAction: () => context.go(GuardianPaths.reports),
      child: StateSwitcher(
        child: switch (apps) {
          PanelLoading<DeviceApps>() => const SkeletonListGroup(
            key: ValueKey<String>('apps-carregando'),
          ),
          PanelFailed<DeviceApps>(:final failure) => AppPanel(
            key: const ValueKey<String>('apps-erro'),
            child: ErrorState(
              compact: true,
              title: 'Não foi possível carregar os apps',
              message: failure.message,
              onRetry: onRetry,
            ),
          ),
          PanelLoaded<DeviceApps>() when top.isEmpty => AppPanel(
            key: const ValueKey<String>('apps-vazio'),
            child: EmptyState(
              compact: true,
              icon: AppIcons.apps,
              title: 'Nenhum uso registrado hoje',
              message: 'Os apps que $childName usar hoje aparecem aqui, do mais usado ao menos.',
            ),
          ),
          PanelLoaded<DeviceApps>() => AppListGroup(
            key: const ValueKey<String>('apps-lista'),
            children: <Widget>[
              for (final AppEntry app in top)
                AppListRow(
                  leading: AppIconView.forApp(app, size: AppSizes.iconTile),
                  title: app.label,
                  titleStyle: context.text.bodyLarge,
                  trailing: Text(
                    formatDurationMs(app.todayMs),
                    style: context.textStyles.metricSmall,
                  ),
                  below: UsageBar(fraction: app.todayMs / maxMs),
                ),
            ],
          ),
        },
      ),
    );
  }
}
