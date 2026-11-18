part of 'guardian_dashboard_bloc.dart';

/// Painel do responsavel para o aparelho em foco.
final class GuardianDashboardState extends Equatable {
  const GuardianDashboardState({
    this.deviceId,
    this.device,
    this.connection,
    this.policy = const PanelLoading<VersionedPolicy>(),
    this.apps = const PanelLoading<DeviceApps>(),
    this.recentAlerts = const PanelLoading<List<GuardianAlert>>(),
    this.commands = ActiveCommands.none,
    this.command = const ActionIdle(),
  });

  /// Aparelho em foco.
  final String? deviceId;

  /// Ultimo retrato do aparelho em foco, ou nulo enquanto a lista nao chegou.
  final ChildDevice? device;

  /// Situacao da conexao do aparelho em foco.
  final DeviceConnection? connection;

  /// Politica em vigor, para saber dos comandos ativos.
  final PanelState<VersionedPolicy> policy;

  /// Inventario de apps, para os mais usados de hoje.
  final PanelState<DeviceApps> apps;
  final PanelState<List<GuardianAlert>> recentAlerts;

  /// Comandos em vigor (pausa, suspensao, tempo extra de hoje).
  final ActiveCommands commands;

  /// Andamento do ultimo comando enviado.
  final ActionStatus command;

  /// Tempo de hoje do aparelho em foco.
  TodayUsage? get usage {
    final ChildDevice? current = device;
    return current == null ? null : TodayUsage.of(current);
  }

  /// O painel ja tem o aparelho [deviceId] para mostrar.
  bool isShowing(String deviceId) => this.deviceId == deviceId && device != null;

  GuardianDashboardState copyWith({
    ChildDevice? device,
    DeviceConnection? connection,
    PanelState<VersionedPolicy>? policy,
    PanelState<DeviceApps>? apps,
    PanelState<List<GuardianAlert>>? recentAlerts,
    ActiveCommands? commands,
    ActionStatus? command,
  }) {
    return GuardianDashboardState(
      deviceId: deviceId,
      device: device ?? this.device,
      connection: connection ?? this.connection,
      policy: policy ?? this.policy,
      apps: apps ?? this.apps,
      recentAlerts: recentAlerts ?? this.recentAlerts,
      commands: commands ?? this.commands,
      command: command ?? this.command,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    deviceId,
    device,
    connection,
    policy,
    apps,
    recentAlerts,
    commands,
    command,
  ];
}
