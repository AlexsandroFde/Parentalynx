import '../../../../core/json/json_reader.dart';

// Objetos de transferencia do aparelho no formato do protocolo (secao 4.1). Espelham o JSON:
// campos opcionais ficam nulos e os codigos chegam como texto. O `ChildDeviceMapper` aplica os
// valores padrao e converte os codigos.

final class DevicePermissionsDto {
  const DevicePermissionsDto({
    this.usageAccess,
    this.accessibility,
    this.overlay,
    this.notifications,
    this.batteryOptimizationIgnored,
    this.deviceAdmin,
    this.exactAlarms,
  });

  factory DevicePermissionsDto.fromJson(JsonMap json) {
    bool? flag(String key) => json.has(key) ? json.boolean(key) : null;
    return DevicePermissionsDto(
      usageAccess: flag('usageAccess'),
      accessibility: flag('accessibility'),
      overlay: flag('overlay'),
      notifications: flag('notifications'),
      batteryOptimizationIgnored: flag('batteryOptimizationIgnored'),
      deviceAdmin: flag('deviceAdmin'),
      exactAlarms: flag('exactAlarms'),
    );
  }

  final bool? usageAccess;
  final bool? accessibility;
  final bool? overlay;
  final bool? notifications;
  final bool? batteryOptimizationIgnored;
  final bool? deviceAdmin;
  final bool? exactAlarms;
}

final class DeviceStateDto {
  const DeviceStateDto({
    this.reportedAt,
    this.day,
    this.quotaUsedMs,
    this.totalUsedMs,
    this.extraMs,
    this.limitMs,
    this.remainingMs,
    this.limitReachedAt,
    this.lockState,
    this.lockReleaseAt,
    this.foregroundApp,
    this.screenOn,
    this.batteryPercent,
    this.permissions,
    this.enforcementActive,
    this.issues,
    this.clockTrusted,
  });

  factory DeviceStateDto.fromJson(JsonMap json) {
    final JsonMap? lock = json.objOrNull('lock');
    final JsonMap? permissions = json.objOrNull('permissions');
    final JsonMap? enforcement = json.objOrNull('enforcement');
    return DeviceStateDto(
      reportedAt: json.intOrNull('reportedAt'),
      day: json.strOrNull('day'),
      quotaUsedMs: json.intOrNull('quotaUsedMs'),
      totalUsedMs: json.intOrNull('totalUsedMs'),
      extraMs: json.intOrNull('extraMs'),
      limitMs: json.intOrNull('limitMs'),
      remainingMs: json.intOrNull('remainingMs'),
      limitReachedAt: json.intOrNull('limitReachedAt'),
      lockState: lock?.strOrNull('state'),
      lockReleaseAt: lock?.intOrNull('releaseAt'),
      foregroundApp: json.strOrNull('foregroundApp'),
      screenOn: json.has('screenOn') ? json.boolean('screenOn') : null,
      batteryPercent: json.intOrNull('batteryPercent'),
      permissions: permissions == null ? null : DevicePermissionsDto.fromJson(permissions),
      enforcementActive: enforcement == null || !enforcement.has('active')
          ? null
          : enforcement.boolean('active'),
      issues: enforcement?.strList('issues'),
      clockTrusted: json.has('clockTrusted') ? json.boolean('clockTrusted') : null,
    );
  }

  final int? reportedAt;
  final String? day;
  final int? quotaUsedMs;
  final int? totalUsedMs;
  final int? extraMs;
  final int? limitMs;
  final int? remainingMs;
  final int? limitReachedAt;
  final String? lockState;
  final int? lockReleaseAt;
  final String? foregroundApp;
  final bool? screenOn;
  final int? batteryPercent;
  final DevicePermissionsDto? permissions;
  final bool? enforcementActive;
  final List<String>? issues;
  final bool? clockTrusted;
}

final class ChildDeviceDto {
  const ChildDeviceDto({
    required this.id,
    this.status,
    this.childName,
    this.deviceName,
    this.model,
    this.manufacturer,
    this.androidRelease,
    this.sdkInt,
    this.appVersion,
    this.timezone,
    this.confirmCode,
    this.relink,
    this.createdAt,
    this.approvedAt,
    this.revokedAt,
    this.lastSyncAt,
    this.online,
    this.today,
    this.managementMode,
    this.policyVersion,
    this.appliedPolicyVersion,
    this.policyAppliedAt,
    this.pendingTimeRequests,
    this.state,
  });

  factory ChildDeviceDto.fromJson(JsonMap json) {
    final JsonMap? state = json.objOrNull('state');
    return ChildDeviceDto(
      id: json.str('id'),
      status: json.strOrNull('status'),
      childName: json.strOrNull('childName'),
      deviceName: json.strOrNull('deviceName'),
      model: json.strOrNull('model'),
      manufacturer: json.strOrNull('manufacturer'),
      androidRelease: json.strOrNull('androidRelease'),
      sdkInt: json.intOrNull('sdkInt'),
      appVersion: json.strOrNull('appVersion'),
      timezone: json.strOrNull('timezone'),
      confirmCode: json.strOrNull('confirmCode'),
      relink: json.has('relink') ? json.boolean('relink') : null,
      createdAt: json.intOrNull('createdAt'),
      approvedAt: json.intOrNull('approvedAt'),
      revokedAt: json.intOrNull('revokedAt'),
      lastSyncAt: json.intOrNull('lastSyncAt'),
      online: json.has('online') ? json.boolean('online') : null,
      today: json.strOrNull('today'),
      managementMode: json.strOrNull('managementMode'),
      policyVersion: json.intOrNull('policyVersion'),
      appliedPolicyVersion: json.intOrNull('appliedPolicyVersion'),
      policyAppliedAt: json.intOrNull('policyAppliedAt'),
      pendingTimeRequests: json.intOrNull('pendingTimeRequests'),
      state: state == null ? null : DeviceStateDto.fromJson(state),
    );
  }

  final String id;
  final String? status;
  final String? childName;
  final String? deviceName;
  final String? model;
  final String? manufacturer;
  final String? androidRelease;
  final int? sdkInt;
  final String? appVersion;
  final String? timezone;
  final String? confirmCode;
  final bool? relink;
  final int? createdAt;
  final int? approvedAt;
  final int? revokedAt;
  final int? lastSyncAt;
  final bool? online;
  final String? today;
  final String? managementMode;
  final int? policyVersion;
  final int? appliedPolicyVersion;
  final int? policyAppliedAt;
  final int? pendingTimeRequests;
  final DeviceStateDto? state;
}
