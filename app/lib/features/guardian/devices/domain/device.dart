import '../../../../core/json/json_reader.dart';
import '../../../../shared/domain/policy.dart';

/// Aparelho monitorado visto pelo responsavel (protocolo, secao 4.1).

enum DeviceStatus {
  pending,
  active,
  revoked;

  static DeviceStatus parse(String value) {
    return switch (value) {
      'pending' => DeviceStatus.pending,
      'revoked' => DeviceStatus.revoked,
      _ => DeviceStatus.active,
    };
  }
}

/// Nivel de gerenciamento do aparelho. Define o que o controle consegue garantir.
enum DeviceManagementMode {
  standard('standard', 'Padrão'),
  deviceAdmin('device_admin', 'Padrão com administrador'),
  deviceOwner('device_owner', 'Dispositivo gerenciado');

  const DeviceManagementMode(this.code, this.label);

  final String code;
  final String label;

  static DeviceManagementMode parse(String? value) {
    for (final DeviceManagementMode mode in values) {
      if (mode.code == value) {
        return mode;
      }
    }
    return DeviceManagementMode.standard;
  }

  /// Verdadeiro quando o bloqueio e imposto pelo sistema (suspensao de apps).
  bool get isSystemEnforced => this == DeviceManagementMode.deviceOwner;
}

/// Bloqueio geral em vigor no aparelho.
enum DeviceLockState {
  none('none', 'Liberado'),
  dailyLimit('daily_limit', 'Limite diário atingido'),
  schedule('schedule', 'Fora do horário permitido'),
  manualLock('manual_lock', 'Pausado pelo responsável'),
  tamperLock('tamper_lock', 'Bloqueado por proteção desativada');

  const DeviceLockState(this.code, this.label);

  final String code;
  final String label;

  static DeviceLockState parse(String? value) {
    for (final DeviceLockState state in values) {
      if (state.code == value) {
        return state;
      }
    }
    return DeviceLockState.none;
  }

  bool get isLocked => this != DeviceLockState.none;
}

class DevicePermissions {
  const DevicePermissions({
    required this.usageAccess,
    required this.accessibility,
    required this.overlay,
    required this.notifications,
    required this.batteryOptimizationIgnored,
    required this.deviceAdmin,
    required this.exactAlarms,
  });

  factory DevicePermissions.fromJson(JsonMap json) {
    return DevicePermissions(
      usageAccess: json.boolOr('usageAccess', fallback: false),
      accessibility: json.boolOr('accessibility', fallback: false),
      overlay: json.boolOr('overlay', fallback: false),
      notifications: json.boolOr('notifications', fallback: false),
      batteryOptimizationIgnored: json.boolOr('batteryOptimizationIgnored', fallback: false),
      deviceAdmin: json.boolOr('deviceAdmin', fallback: false),
      exactAlarms: json.boolOr('exactAlarms', fallback: false),
    );
  }

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
}

/// Ultimo retrato enviado pelo aparelho.
class DeviceState {
  const DeviceState({
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

  factory DeviceState.fromJson(JsonMap json) {
    final JsonMap? lock = json.objOrNull('lock');
    final JsonMap? permissions = json.objOrNull('permissions');
    final JsonMap? enforcement = json.objOrNull('enforcement');
    return DeviceState(
      reportedAt: json.intOr('reportedAt', fallback: 0),
      day: json.strOrNull('day') ?? '',
      quotaUsedMs: json.intOr('quotaUsedMs', fallback: 0),
      totalUsedMs: json.intOr('totalUsedMs', fallback: 0),
      extraMs: json.intOr('extraMs', fallback: 0),
      limitMs: json.intOrNull('limitMs'),
      remainingMs: json.intOrNull('remainingMs'),
      limitReachedAt: json.intOrNull('limitReachedAt'),
      lockState: DeviceLockState.parse(lock?.strOrNull('state')),
      lockReleaseAt: lock?.intOrNull('releaseAt'),
      foregroundApp: json.strOrNull('foregroundApp'),
      screenOn: json.boolOr('screenOn', fallback: false),
      batteryPercent: json.intOrNull('batteryPercent'),
      permissions: permissions == null
          ? DevicePermissions.unknown
          : DevicePermissions.fromJson(permissions),
      enforcementActive: enforcement?.boolOr('active', fallback: true) ?? true,
      issues: enforcement == null ? const <String>[] : enforcement.strList('issues'),
      clockTrusted: json.boolOr('clockTrusted', fallback: true),
    );
  }

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
}

class Device {
  const Device({
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
    this.state,
  });

  factory Device.fromJson(JsonMap json) {
    final JsonMap? state = json.objOrNull('state');
    return Device(
      id: json.str('id'),
      status: DeviceStatus.parse(json.strOrNull('status') ?? 'active'),
      childName: json.strOrNull('childName') ?? '',
      deviceName: json.strOrNull('deviceName') ?? '',
      model: json.strOrNull('model') ?? '',
      manufacturer: json.strOrNull('manufacturer') ?? '',
      androidRelease: json.strOrNull('androidRelease') ?? '',
      sdkInt: json.intOr('sdkInt', fallback: 0),
      appVersion: json.strOrNull('appVersion') ?? '',
      timezone: json.strOrNull('timezone') ?? 'UTC',
      confirmCode: json.strOrNull('confirmCode'),
      relink: json.boolOr('relink', fallback: false),
      createdAt: json.intOr('createdAt', fallback: 0),
      approvedAt: json.intOrNull('approvedAt'),
      revokedAt: json.intOrNull('revokedAt'),
      lastSyncAt: json.intOrNull('lastSyncAt'),
      online: json.boolOr('online', fallback: false),
      today: json.strOrNull('today') ?? '',
      managementMode: DeviceManagementMode.parse(json.strOrNull('managementMode')),
      policyVersion: json.intOr('policyVersion', fallback: 0),
      appliedPolicyVersion: json.intOr('appliedPolicyVersion', fallback: 0),
      policyAppliedAt: json.intOrNull('policyAppliedAt'),
      pendingTimeRequests: json.intOr('pendingTimeRequests', fallback: 0),
      state: state == null ? null : DeviceState.fromJson(state),
    );
  }

  final String id;
  final DeviceStatus status;
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
  final DeviceState? state;

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

  /// Verdadeiro quando ha uma versao de politica ainda nao confirmada pelo aparelho.
  bool get policyPending => appliedPolicyVersion < policyVersion;
}

/// Politica de um aparelho com a versao que o servidor guarda.
class DevicePolicy {
  const DevicePolicy({required this.version, required this.policy});

  factory DevicePolicy.fromJson(JsonMap json) {
    return DevicePolicy(
      version: json.integer('policyVersion'),
      policy: Policy.fromJson(json.obj('policy')),
    );
  }

  final int version;
  final Policy policy;
}

/// Aparelho com a sua politica (resposta de `GET /v1/guardian/devices/:id`).
class DeviceDetail {
  const DeviceDetail({required this.device, required this.policy});

  factory DeviceDetail.fromJson(JsonMap json) {
    return DeviceDetail(
      device: Device.fromJson(json.obj('device')),
      policy: DevicePolicy.fromJson(json),
    );
  }

  final Device device;
  final DevicePolicy policy;
}
