import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/feedback_views.dart';

/// Icone e tom de um tipo de alerta. O tom reforca a gravidade, mas o icone e o titulo ja
/// dizem do que se trata.
class AlertVisual {
  const AlertVisual(this.icon, this.tone);

  final IconData icon;
  final Tone tone;

  static AlertVisual forType(String type) {
    return switch (type) {
      'limit_reached' => const AlertVisual(Icons.hourglass_bottom, Tone.warning),
      'low_time' => const AlertVisual(Icons.timelapse, Tone.info),
      'blocked_app_attempt' => const AlertVisual(Icons.block, Tone.warning),
      'time_request' => const AlertVisual(Icons.more_time, Tone.info),
      'sync_stale' => const AlertVisual(Icons.sync_problem, Tone.warning),
      'device_offline' => const AlertVisual(Icons.cloud_off_outlined, Tone.danger),
      'permission_changed' => const AlertVisual(Icons.admin_panel_settings_outlined, Tone.warning),
      'enforcement_failure' => const AlertVisual(Icons.report_problem_outlined, Tone.danger),
      'security_event' => const AlertVisual(Icons.gpp_maybe_outlined, Tone.danger),
      'new_app_installed' => const AlertVisual(Icons.install_mobile_outlined, Tone.info),
      'policy_changed' => const AlertVisual(Icons.tune, Tone.info),
      'device_linked' => const AlertVisual(Icons.link, Tone.success),
      _ => const AlertVisual(Icons.notifications_none, Tone.neutral),
    };
  }
}

/// Circulo com o icone do tipo de alerta.
class AlertIcon extends StatelessWidget {
  const AlertIcon({required this.type, this.size = 40, super.key});

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AlertVisual visual = AlertVisual.forType(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: visual.tone.background(context), shape: BoxShape.circle),
      child: Icon(visual.icon, size: size * 0.52, color: visual.tone.foreground(context)),
    );
  }
}
