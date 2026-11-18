import 'package:equatable/equatable.dart';

import 'management_level.dart';

/// Estado das permissoes especiais de que o controle depende.
final class PermissionFacts extends Equatable {
  const PermissionFacts({
    required this.usageAccess,
    required this.accessibility,
    required this.overlay,
    required this.notifications,
    required this.batteryOptimizationIgnored,
    required this.deviceAdmin,
    required this.deviceOwner,
    required this.exactAlarms,
    required this.restrictedSettingsLikely,
  });

  final bool usageAccess;
  final bool accessibility;
  final bool overlay;
  final bool notifications;
  final bool batteryOptimizationIgnored;
  final bool deviceAdmin;
  final bool deviceOwner;
  final bool exactAlarms;

  /// App instalado por fora da loja em Android 13 ou superior: a acessibilidade pode aparecer
  /// desabilitada ate liberar as "configuracoes restritas".
  final bool restrictedSettingsLikely;

  ManagementLevel get management {
    if (deviceOwner) {
      return ManagementLevel.deviceOwner;
    }
    return deviceAdmin ? ManagementLevel.deviceAdmin : ManagementLevel.standard;
  }

  @override
  List<Object?> get props => <Object?>[
    usageAccess,
    accessibility,
    overlay,
    notifications,
    batteryOptimizationIgnored,
    deviceAdmin,
    deviceOwner,
    exactAlarms,
    restrictedSettingsLikely,
  ];
}
