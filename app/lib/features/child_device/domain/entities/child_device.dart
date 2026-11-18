import 'package:equatable/equatable.dart';

import '../../../device_sync/domain/entities/policy_sync_status.dart';

/// Situacao do vinculo de um aparelho com a conta.
enum DeviceLinkStatus { pending, active, revoked }

/// Nivel de gerenciamento do aparelho. Define o que o controle consegue garantir.
enum DeviceManagementMode {
  standard('Padrão'),
  deviceAdmin('Padrão com administrador'),
  deviceOwner('Dispositivo gerenciado');

  const DeviceManagementMode(this.label);

  final String label;

  /// Verdadeiro quando o bloqueio e imposto pelo sistema (suspensao de apps).
  bool get isSystemEnforced => this == DeviceManagementMode.deviceOwner;
}

/// Bloqueio geral em vigor no aparelho.
enum DeviceLockState {
  none('Liberado'),
  dailyLimit('Limite diário atingido'),
  schedule('Fora do horário permitido'),
  manualLock('Pausado pelo responsável'),
  tamperLock('Bloqueado por proteção desativada');

  const DeviceLockState(this.label);

  final String label;

  bool get isLocked => this != DeviceLockState.none;
}

/// Permissoes especiais que o controle usa no aparelho da crianca.
final class DevicePermissions extends Equatable {
  const DevicePermissions({
    required this.usageAccess,
    required this.accessibility,
    required this.overlay,
    required this.notifications,
    required this.batteryOptimizationIgnored,
    required this.deviceAdmin,
    required this.exactAlarms,
  });

  static const DevicePermissions unknown = DevicePermissions(
    usageAccess: false,
    accessibility: false,
    overlay: false,
    notifications: false,
    batteryOptimizationIgnored: false,
    deviceAdmin: false,
    exactAlarms: false,
  );

  final bool usageAccess;
  final bool accessibility;
  final bool overlay;
  final bool notifications;
  final bool batteryOptimizationIgnored;
  final bool deviceAdmin;
  final bool exactAlarms;

  @override
  List<Object?> get props => <Object?>[
    usageAccess,
    accessibility,
    overlay,
    notifications,
    batteryOptimizationIgnored,
    deviceAdmin,
    exactAlarms,
  ];
}

/// Ultimo retrato enviado pelo aparelho: uso do dia, bloqueio e saude do controle.
final class DeviceSnapshot extends Equatable {
  const DeviceSnapshot({
    required this.reportedAt,
    required this.day,
    required this.quotaUsedMs,
    required this.totalUsedMs,
    required this.extraMs,
    required this.lockState,
    required this.screenOn,
    required this.permissions,
    required this.enforcementActive,
    required this.issues,
    required this.clockTrusted,
    this.limitMs,
    this.remainingMs,
    this.limitReachedAt,
    this.lockReleaseAt,
    this.foregroundApp,
    this.batteryPercent,
  });

  final int reportedAt;
  final String day;
  final int quotaUsedMs;
  final int totalUsedMs;
  final int extraMs;

  /// Limite efetivo do dia. Nulo quando o limite esta desligado.
  final int? limitMs;
  final int? remainingMs;
  final int? limitReachedAt;
  final DeviceLockState lockState;
  final int? lockReleaseAt;
  final String? foregroundApp;
  final bool screenOn;
  final int? batteryPercent;
  final DevicePermissions permissions;
  final bool enforcementActive;

  /// Problemas de aplicacao das regras (`accessibility_disabled`, ...).
  final List<String> issues;
  final bool clockTrusted;

  /// Fracao da cota ja usada, de 0 a 1. Zero quando nao ha limite.
  double get usedFraction {
    final int? limit = limitMs;
    if (limit == null || limit <= 0) {
      return 0;
    }
    return (quotaUsedMs / limit).clamp(0.0, 1.0);
  }

  /// Verdadeiro quando alguma protecao essencial esta desativada.
  bool get isDegraded => issues.isNotEmpty || !enforcementActive;

  @override
  List<Object?> get props => <Object?>[
    reportedAt,
    day,
    quotaUsedMs,
    totalUsedMs,
    extraMs,
    limitMs,
    remainingMs,
    limitReachedAt,
    lockState,
    lockReleaseAt,
    foregroundApp,
    screenOn,
    batteryPercent,
    permissions,
    enforcementActive,
    issues,
    clockTrusted,
  ];
}

/// Aparelho monitorado visto pelo responsavel (protocolo, secao 4.1).
final class ChildDevice extends Equatable {
  const ChildDevice({
    required this.id,
    required this.status,
    required this.childName,
    required this.deviceName,
    required this.model,
    required this.manufacturer,
    required this.androidRelease,
    required this.sdkInt,
    required this.appVersion,
    required this.timezone,
    required this.relink,
    required this.createdAt,
    required this.online,
    required this.today,
    required this.managementMode,
    required this.policyVersion,
    required this.appliedPolicyVersion,
    required this.pendingTimeRequests,
    this.confirmCode,
    this.approvedAt,
    this.revokedAt,
    this.lastSyncAt,
    this.policyAppliedAt,
    this.snapshot,
  });

  final String id;
  final DeviceLinkStatus status;
  final String childName;
  final String deviceName;
  final String model;
  final String manufacturer;
  final String androidRelease;
  final int sdkInt;
  final String appVersion;
  final String timezone;

  /// Numero de confirmacao mostrado nos dois aparelhos. So em vinculo pendente.
  final String? confirmCode;

  /// O pedido pendente e de um aparelho ja conhecido da conta.
  final bool relink;
  final int createdAt;
  final int? approvedAt;
  final int? revokedAt;
  final int? lastSyncAt;
  final bool online;

  /// Dia da cota corrente no fuso da politica, calculado pelo servidor.
  final String today;
  final DeviceManagementMode managementMode;
  final int policyVersion;
  final int appliedPolicyVersion;
  final int? policyAppliedAt;
  final int pendingTimeRequests;

  /// Nulo enquanto o aparelho nao sincronizou pela primeira vez.
  final DeviceSnapshot? snapshot;

  bool get isActive => status == DeviceLinkStatus.active;

  bool get isPending => status == DeviceLinkStatus.pending;

  /// Nome para mostrar: o da crianca, ou o do aparelho enquanto nao ha nome.
  String get displayName => childName.isNotEmpty ? childName : deviceName;

  /// Descricao do hardware: "motorola moto g54, Android 14".
  String get hardwareLabel {
    final String name = <String>[
      manufacturer,
      model,
    ].where((String part) => part.isNotEmpty).join(' ');
    return androidRelease.isEmpty ? name : '$name, Android $androidRelease';
  }

  /// Confirmacao de aplicacao da politica no aparelho.
  PolicySyncStatus get policySync {
    return PolicySyncStatus(
      serverVersion: policyVersion,
      appliedVersion: appliedPolicyVersion,
      deviceOnline: online,
      appliedAt: policyAppliedAt,
    );
  }

  /// Verdadeiro quando ha uma versao de politica ainda nao confirmada pelo aparelho.
  bool get policyPending => policySync.isPending;

  @override
  List<Object?> get props => <Object?>[
    id,
    status,
    childName,
    deviceName,
    model,
    manufacturer,
    androidRelease,
    sdkInt,
    appVersion,
    timezone,
    confirmCode,
    relink,
    createdAt,
    approvedAt,
    revokedAt,
    lastSyncAt,
    online,
    today,
    managementMode,
    policyVersion,
    appliedPolicyVersion,
    policyAppliedAt,
    pendingTimeRequests,
    snapshot,
  ];
}
