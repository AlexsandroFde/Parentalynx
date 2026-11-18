import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/route_paths.dart';
import '../../../../../core/time/formatters.dart';
import '../../../../../shared/design_system/design_system.dart';
import '../../../../notifications/domain/entities/guardian_alert.dart';
import '../../../../notifications/presentation/widgets/alert_icon.dart';
import '../../bloc/dashboard/panel_state.dart';

/// Previa dos alertas mais recentes da conta, com o mesmo icone e tom da central de alertas.
/// Os nao lidos levam a etiqueta "Novo".
class DashboardRecentAlerts extends StatelessWidget {
  const DashboardRecentAlerts({
    required this.alerts,
    required this.now,
    required this.onRetry,
    super.key,
  });

  final PanelState<List<GuardianAlert>> alerts;
  final DateTime now;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    void openAlerts() => context.go(GuardianPaths.alerts);
    return AppSection(
      title: 'Alertas recentes',
      actionLabel: 'Ver todos',
      onAction: openAlerts,
      child: StateSwitcher(
        child: switch (alerts) {
          PanelLoading<List<GuardianAlert>>() => const SkeletonListGroup(
            key: ValueKey<String>('alertas-carregando'),
            rows: 2,
          ),
          PanelFailed<List<GuardianAlert>>(:final failure) => AppPanel(
            key: const ValueKey<String>('alertas-erro'),
            child: ErrorState(
              compact: true,
              title: 'Não foi possível carregar os alertas',
              message: failure.message,
              onRetry: onRetry,
            ),
          ),
          PanelLoaded<List<GuardianAlert>>(:final List<GuardianAlert> value) when value.isEmpty =>
            const AppPanel(
              key: ValueKey<String>('alertas-vazio'),
              child: EmptyState(
                compact: true,
                icon: AppIcons.notificationNone,
                title: 'Nenhum alerta recente',
                message: 'Limite atingido, pedidos de tempo e avisos de proteção aparecem aqui.',
              ),
            ),
          PanelLoaded<List<GuardianAlert>>(:final List<GuardianAlert> value) => AppListGroup(
            key: const ValueKey<String>('alertas-lista'),
            children: <Widget>[
              for (final GuardianAlert alert in value)
                AppListRow(
                  leading: AppIconTile(
                    icon: AlertVisual.forType(alert.type).icon,
                    tone: AlertVisual.forType(alert.type).tone,
                  ),
                  title: alert.title,
                  subtitle: <String>[
                    if (alert.body.isNotEmpty) alert.body,
                    formatRelativeMs(alert.createdAt, now: now),
                  ].join('\n'),
                  trailing: alert.isRead
                      ? null
                      : const StatusBadge(label: 'Novo', tone: Tone.info, showIcon: false),
                  showChevron: false,
                  onTap: openAlerts,
                ),
            ],
          ),
        },
      ),
    );
  }
}
