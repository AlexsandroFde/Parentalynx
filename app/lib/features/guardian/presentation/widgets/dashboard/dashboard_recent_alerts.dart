import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/route_paths.dart';
import '../../../../../core/time/formatters.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/feedback_views.dart';
import '../../../../../shared/widgets/form_widgets.dart';
import '../../../../notifications/domain/entities/guardian_alert.dart';
import '../../bloc/dashboard/panel_state.dart';

/// Icone e tom de um tipo de alerta na previa do painel.
({IconData icon, Tone tone}) _alertVisual(String type) {
  return switch (type) {
    'limit_reached' => (icon: Icons.timer_off_outlined, tone: Tone.warning),
    'low_time' => (icon: Icons.hourglass_bottom, tone: Tone.info),
    'blocked_app_attempt' => (icon: Icons.block, tone: Tone.danger),
    'sync_stale' || 'device_offline' => (icon: Icons.cloud_off_outlined, tone: Tone.warning),
    'policy_changed' => (icon: Icons.tune, tone: Tone.info),
    'enforcement_failure' => (icon: Icons.gpp_bad_outlined, tone: Tone.danger),
    'time_request' => (icon: Icons.more_time, tone: Tone.info),
    'permission_changed' => (icon: Icons.admin_panel_settings_outlined, tone: Tone.warning),
    'new_app_installed' => (icon: Icons.apps_outlined, tone: Tone.info),
    'security_event' => (icon: Icons.security, tone: Tone.danger),
    'device_linked' => (icon: Icons.link, tone: Tone.success),
    _ => (icon: Icons.notifications_none, tone: Tone.neutral),
  };
}

/// Previa dos alertas mais recentes da conta.
class DashboardRecentAlerts extends StatelessWidget {
  const DashboardRecentAlerts({required this.alerts, required this.now, super.key});

  final PanelState<List<GuardianAlert>> alerts;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget content = switch (alerts) {
      PanelLoading<List<GuardianAlert>>() => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      PanelFailed<List<GuardianAlert>>() => Text(
        'Não foi possível carregar os alertas.',
        style: muted,
      ),
      PanelLoaded<List<GuardianAlert>>(:final List<GuardianAlert> value) when value.isEmpty => Text(
        'Nenhum alerta recente.',
        style: muted,
      ),
      PanelLoaded<List<GuardianAlert>>(:final List<GuardianAlert> value) => Column(
        children: <Widget>[
          for (final GuardianAlert alert in value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _alertVisual(alert.type).tone.background(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _alertVisual(alert.type).icon,
                      size: 20,
                      color: _alertVisual(alert.type).tone.foreground(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(alert.title, style: theme.textTheme.titleSmall),
                        Text(alert.body, style: theme.textTheme.bodySmall),
                        Text(
                          formatRelativeMs(alert.createdAt, now: now),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
      title: 'Alertas recentes',
      trailing: TextButton(
        onPressed: () => context.go(GuardianPaths.alerts),
        child: const Text('Ver todos'),
      ),
      child: content,
    );
  }
}
