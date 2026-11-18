import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/device_event.dart';

/// Icone e tom de um evento do aparelho. Tentativa bloqueada e problemas de seguranca usam
/// [Tone.danger]; limite e pouco tempo, [Tone.warning]; horario e pausa combinados,
/// [Tone.rest]; o que voltou a valer, [Tone.success]. O titulo em texto diz o que houve.
({IconData icon, Tone tone}) eventVisual(DeviceEvent event) {
  final EventDetails details = event.details;
  return switch (event.type) {
    'blocked_attempt' => (icon: AppIcons.blocked, tone: Tone.danger),
    'limit_reached' || 'app_limit_reached' => (icon: AppIcons.dailyLimit, tone: Tone.warning),
    'low_time' => (icon: AppIcons.timeRunningOut, tone: Tone.warning),
    'time_request' => (icon: AppIcons.timeRequest, tone: Tone.info),
    'lock_started' => switch (details.reason) {
      'schedule' => (icon: AppIcons.scheduledLock, tone: Tone.rest),
      'manual_lock' => (icon: AppIcons.pause, tone: Tone.rest),
      'daily_limit' || 'app_limit' => (icon: AppIcons.dailyLimit, tone: Tone.warning),
      'tamper_lock' => (icon: AppIcons.protectionOff, tone: Tone.danger),
      _ => (icon: AppIcons.lock, tone: Tone.neutral),
    },
    'lock_ended' => (icon: AppIcons.unlock, tone: Tone.success),
    'policy_applied' => (icon: AppIcons.synced, tone: Tone.success),
    'policy_apply_failed' => (icon: AppIcons.syncProblem, tone: Tone.danger),
    'enforcement_issue' => (icon: AppIcons.problem, tone: Tone.danger),
    'permission_changed' =>
      details.granted ?? false
          ? (icon: AppIcons.protectionGood, tone: Tone.success)
          : (icon: AppIcons.protectionWeak, tone: Tone.warning),
    'admin_auth_failed' => (icon: AppIcons.key, tone: Tone.danger),
    'clock_changed' => (icon: AppIcons.clock, tone: Tone.warning),
    'local_override' => (icon: AppIcons.unlock, tone: Tone.warning),
    'unlinked_locally' => (icon: AppIcons.unlink, tone: Tone.danger),
    'management_mode_changed' => (icon: AppIcons.admin, tone: Tone.warning),
    'app_installed' => (icon: AppIcons.install, tone: Tone.info),
    'app_removed' => (icon: AppIcons.removeCircle, tone: Tone.neutral),
    'agent_started' => (icon: AppIcons.protectionGood, tone: Tone.success),
    'device_boot' || 'device_shutdown' => (icon: AppIcons.device, tone: Tone.neutral),
    _ => (icon: AppIcons.info, tone: Tone.neutral),
  };
}
