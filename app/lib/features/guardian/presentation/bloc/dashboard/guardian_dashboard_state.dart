part of 'guardian_dashboard_bloc.dart';

/// Acao rapida do painel enviada ao aparelho em foco.
enum DashboardCommandKind { extraTime, pause, resume, suspend, endSuspension }

/// Ultimo comando rapido enviado: o tipo e, no tempo extra, os minutos.
///
/// A tela usa para mostrar o andamento no botao que a pessoa tocou e para dizer qual operacao
/// falhou.
final class DashboardCommand extends Equatable {
  const DashboardCommand(this.kind, {this.minutes});

  final DashboardCommandKind kind;

  /// Minutos do tempo extra ou da suspensao.
  final int? minutes;

  @override
  List<Object?> get props => <Object?>[kind, minutes];
}

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
    this.lastCommand,
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

  /// Ultimo comando enviado (em andamento ou concluido).
  final DashboardCommand? lastCommand;

  /// Comando em andamento agora, ou nulo.
  DashboardCommand? get runningCommand => command.isRunning ? lastCommand : null;

  /// Tempo de hoje do aparelho em foco.
  TodayUsage? get usage {
    final ChildDevice? current = device;
    return current == null ? null : TodayUsage.of(current);
  }

  /// Confirmacao das regras no aparelho em foco.
  ///
  /// Conta tambem a versao devolvida por um comando que a lista de aparelhos ainda nao trouxe:
  /// a pausa ou o tempo extra so valem quando o aparelho confirmar essa versao.
  PolicySyncStatus? get policySync {
    final ChildDevice? current = device;
    if (current == null) {
      return null;
    }
    final PolicySyncStatus base = current.policySync;
    final int? commanded = policy.valueOrNull?.version;
    if (commanded == null || commanded <= base.serverVersion) {
      return base;
    }
    return PolicySyncStatus(
      serverVersion: commanded,
      appliedVersion: base.appliedVersion,
      deviceOnline: base.deviceOnline,
      appliedAt: base.appliedAt,
    );
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
    DashboardCommand? lastCommand,
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
      lastCommand: lastCommand ?? this.lastCommand,
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
    lastCommand,
  ];
}
