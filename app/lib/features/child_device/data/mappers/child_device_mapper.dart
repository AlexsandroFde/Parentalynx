import '../../domain/entities/child_device.dart';
import '../dto/child_device_dto.dart';

/// Converte o aparelho do protocolo na entidade, aplicando os valores padrao e os codigos.
abstract final class ChildDeviceMapper {
  static ChildDevice device(ChildDeviceDto dto) {
    final DeviceStateDto? state = dto.state;
    return ChildDevice(
      id: dto.id,
      status: linkStatus(dto.status),
      childName: dto.childName ?? '',
      deviceName: dto.deviceName ?? '',
      model: dto.model ?? '',
      manufacturer: dto.manufacturer ?? '',
      androidRelease: dto.androidRelease ?? '',
      sdkInt: dto.sdkInt ?? 0,
      appVersion: dto.appVersion ?? '',
      timezone: dto.timezone ?? 'UTC',
      confirmCode: dto.confirmCode,
      relink: dto.relink ?? false,
      createdAt: dto.createdAt ?? 0,
      approvedAt: dto.approvedAt,
      revokedAt: dto.revokedAt,
      lastSyncAt: dto.lastSyncAt,
      online: dto.online ?? false,
      today: dto.today ?? '',
      managementMode: managementMode(dto.managementMode),
      policyVersion: dto.policyVersion ?? 0,
      appliedPolicyVersion: dto.appliedPolicyVersion ?? 0,
      policyAppliedAt: dto.policyAppliedAt,
      pendingTimeRequests: dto.pendingTimeRequests ?? 0,
      snapshot: state == null ? null : snapshot(state),
    );
  }

  static DeviceSnapshot snapshot(DeviceStateDto dto) {
    final DevicePermissionsDto? permissions = dto.permissions;
    return DeviceSnapshot(
      reportedAt: dto.reportedAt ?? 0,
      day: dto.day ?? '',
      quotaUsedMs: dto.quotaUsedMs ?? 0,
      totalUsedMs: dto.totalUsedMs ?? 0,
      extraMs: dto.extraMs ?? 0,
      limitMs: dto.limitMs,
      remainingMs: dto.remainingMs,
      limitReachedAt: dto.limitReachedAt,
      lockState: lockState(dto.lockState),
      lockReleaseAt: dto.lockReleaseAt,
      foregroundApp: dto.foregroundApp,
      screenOn: dto.screenOn ?? false,
      batteryPercent: dto.batteryPercent,
      permissions: permissions == null
          ? DevicePermissions.unknown
          : DevicePermissions(
              usageAccess: permissions.usageAccess ?? false,
              accessibility: permissions.accessibility ?? false,
              overlay: permissions.overlay ?? false,
              notifications: permissions.notifications ?? false,
              batteryOptimizationIgnored: permissions.batteryOptimizationIgnored ?? false,
              deviceAdmin: permissions.deviceAdmin ?? false,
              exactAlarms: permissions.exactAlarms ?? false,
            ),
      enforcementActive: dto.enforcementActive ?? true,
      issues: dto.issues ?? const <String>[],
      clockTrusted: dto.clockTrusted ?? true,
    );
  }

  static DeviceLinkStatus linkStatus(String? code) {
    return switch (code) {
      'pending' => DeviceLinkStatus.pending,
      'revoked' => DeviceLinkStatus.revoked,
      _ => DeviceLinkStatus.active,
    };
  }

  static DeviceManagementMode managementMode(String? code) {
    return switch (code) {
      'device_admin' => DeviceManagementMode.deviceAdmin,
      'device_owner' => DeviceManagementMode.deviceOwner,
      _ => DeviceManagementMode.standard,
    };
  }

  static DeviceLockState lockState(String? code) {
    return switch (code) {
      'daily_limit' => DeviceLockState.dailyLimit,
      'schedule' => DeviceLockState.schedule,
      'manual_lock' => DeviceLockState.manualLock,
      'tamper_lock' => DeviceLockState.tamperLock,
      _ => DeviceLockState.none,
    };
  }
}
