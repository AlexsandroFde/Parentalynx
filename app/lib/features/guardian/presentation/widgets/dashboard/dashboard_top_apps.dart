import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/route_paths.dart';
import '../../../../../core/time/formatters.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/form_widgets.dart';
import '../../../../app_management/domain/entities/app_entry.dart';
import '../../../../app_management/presentation/widgets/app_icon_view.dart';
import '../../bloc/dashboard/panel_state.dart';

/// Apps mais usados hoje, com uma barra proporcional ao mais usado.
class DashboardTopApps extends StatelessWidget {
  const DashboardTopApps({required this.apps, super.key});

  final PanelState<DeviceApps> apps;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AppEntry> top = apps.valueOrNull?.topToday() ?? const <AppEntry>[];
    final int maxMs = top.isEmpty ? 1 : top.first.todayMs;
    final Widget content = switch (apps) {
      PanelLoading<DeviceApps>() => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      PanelFailed<DeviceApps>() => Text(
        'Não foi possível carregar os apps. Puxe para atualizar.',
        style: theme.textTheme.bodyMedium,
      ),
      PanelLoaded<DeviceApps>() when top.isEmpty => Text(
        'Nenhum uso registrado hoje.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      PanelLoaded<DeviceApps>() => Column(
        children: <Widget>[
          for (final AppEntry app in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  AppIconView.forApp(app, size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                app.label,
                                style: theme.textTheme.bodyLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(formatDurationMs(app.todayMs), style: theme.textTheme.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (app.todayMs / maxMs).clamp(0.0, 1.0),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    };
    return SectionCard(
      title: 'Mais usados hoje',
      trailing: TextButton(
        onPressed: () => context.go(GuardianPaths.reports),
        child: const Text('Relatórios'),
      ),
      child: content,
    );
  }
}
