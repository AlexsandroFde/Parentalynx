import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';

/// Icone e tom de um tipo de alerta. O tom reforca a gravidade, mas o icone e o titulo ja
/// dizem do que se trata (a cor nunca e o unico sinal).
///
/// Tentativa bloqueada, falha das regras e eventos de seguranca usam [Tone.danger]; limite,
/// pouco tempo e aparelho sem conexao usam [Tone.warning]; pedidos e avisos informativos
/// usam [Tone.info]. Usado tambem pela previa de alertas do painel.
class AlertVisual {
  const AlertVisual(this.icon, this.tone);

  final IconData icon;
  final Tone tone;

  static AlertVisual forType(String type) {
    return switch (type) {
      'limit_reached' => const AlertVisual(AppIcons.timeRunningOut, Tone.warning),
      'low_time' => const AlertVisual(AppIcons.elapsed, Tone.warning),
      'blocked_app_attempt' => const AlertVisual(AppIcons.blocked, Tone.danger),
      'time_request' => const AlertVisual(AppIcons.timeRequest, Tone.info),
      'sync_stale' => const AlertVisual(AppIcons.syncProblem, Tone.warning),
      'device_offline' => const AlertVisual(AppIcons.offline, Tone.warning),
      'permission_changed' => const AlertVisual(AppIcons.protectionWeak, Tone.warning),
      'enforcement_failure' => const AlertVisual(AppIcons.protectionOff, Tone.danger),
      'security_event' => const AlertVisual(AppIcons.security, Tone.danger),
      'new_app_installed' => const AlertVisual(AppIcons.newApp, Tone.info),
      'policy_changed' => const AlertVisual(AppIcons.rules, Tone.info),
      'device_linked' => const AlertVisual(AppIcons.link, Tone.success),
      _ => const AlertVisual(AppIcons.notification, Tone.neutral),
    };
  }
}

/// Icone do tipo de alerta, na cor da gravidade (cinza quando so informa). Decorativo: o
/// titulo do alerta ao lado diz do que se trata.
class AlertIcon extends StatelessWidget {
  const AlertIcon({required this.type, this.size = AppSizes.rowIcon, super.key});

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AlertVisual visual = AlertVisual.forType(type);
    return AppIconTile(icon: visual.icon, tone: visual.tone, size: size);
  }
}
