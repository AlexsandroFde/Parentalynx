import '../../../../core/platform/native_providers.dart';
import '../domain/child_models.dart';

// Conversao dos tipos gerados pelo Pigeon para os modelos do modo crianca.

DeviceIdentity deviceIdentityFrom(NativeDeviceInfo info) {
  return DeviceIdentity(
    name: info.name,
    model: info.model,
    manufacturer: info.manufacturer,
    androidRelease: info.androidRelease,
    sdkInt: info.sdkInt,
    appVersion: info.appVersion,
    timezone: info.timezone,
    hardwareId: info.hardwareId,
  );
}

PermissionFacts permissionFactsFrom(PermissionSnapshot snapshot) {
  return PermissionFacts(
    usageAccess: snapshot.usageAccess,
    accessibility: snapshot.accessibility,
    overlay: snapshot.overlay,
    notifications: snapshot.notifications,
    batteryOptimizationIgnored: snapshot.batteryOptimizationIgnored,
    deviceAdmin: snapshot.deviceAdmin,
    deviceOwner: snapshot.deviceOwner,
    exactAlarms: snapshot.exactAlarms,
    restrictedSettingsLikely: snapshot.restrictedSettingsLikely,
  );
}

ManagementLevel managementLevelFrom(ManagementMode mode) {
  return switch (mode) {
    ManagementMode.standard => ManagementLevel.standard,
    ManagementMode.deviceAdmin => ManagementLevel.deviceAdmin,
    ManagementMode.deviceOwner => ManagementLevel.deviceOwner,
  };
}

ChildLock childLockFrom(LockState state) {
  return switch (state) {
    LockState.none => ChildLock.none,
    LockState.dailyLimit => ChildLock.dailyLimit,
    LockState.schedule => ChildLock.schedule,
    LockState.manualLock => ChildLock.manualLock,
    LockState.tamperLock => ChildLock.tamperLock,
  };
}

ChildStatus childStatusFrom(AgentStatus status) {
  return ChildStatus(
    active: status.active,
    childName: status.childName,
    guardianName: status.guardianName,
    management: managementLevelFrom(status.managementMode),
    lock: childLockFrom(status.lockState),
    releaseAtMs: status.releaseAtMs,
    activeScheduleLabel: status.activeScheduleLabel,
    limitEnabled: status.limitEnabled,
    limitMs: status.limitMs,
    extraMs: status.extraMs,
    quotaUsedMs: status.quotaUsedMs,
    totalUsedMs: status.totalUsedMs,
    remainingMs: status.remainingMs,
    day: status.day,
    nextResetAtMs: status.nextResetAtMs,
    policyVersion: status.policyVersion,
    lastSyncAtMs: status.lastSyncAtMs,
    lastSyncOk: status.lastSyncOk,
    lastSyncError: status.lastSyncError,
    suspensionUntilMs: status.suspensionUntilMs,
    suspensionScopes: List<String>.unmodifiable(status.suspensionScopes),
    localOverrideUntilMs: status.localOverrideUntilMs,
    permissions: permissionFactsFrom(status.permissions),
    issues: List<String>.unmodifiable(status.issues),
    clockTrusted: status.clockTrusted,
    nowMs: status.nowMs,
    nextBlockAtMs: status.nextBlockAtMs,
    nextBlockLabel: status.nextBlockLabel,
    blockedAppsCount: status.blockedAppsCount,
    exceptionAppsCount: status.exceptionAppsCount,
    managedBrowserEnabled: status.managedBrowserEnabled,
  );
}

AppUsage appUsageFrom(UsageEntry entry) {
  return AppUsage(
    packageName: entry.packageName,
    label: entry.label,
    ms: entry.ms,
    opens: entry.opens,
  );
}

AllowedApp allowedAppFrom(NativeAppInfo info) {
  return AllowedApp(packageName: info.packageName, label: info.label, category: info.category);
}

TimeRequest timeRequestFrom(TimeRequestInfo info) {
  return TimeRequest(
    id: info.id,
    createdAtMs: info.createdAtMs,
    minutes: info.minutes,
    message: info.message,
    state: switch (info.status) {
      'approved' => TimeRequestState.approved,
      'denied' => TimeRequestState.denied,
      'expired' => TimeRequestState.expired,
      _ => TimeRequestState.pending,
    },
    grantedMinutes: info.grantedMinutes,
    delivered: info.delivered,
  );
}

AdminAuth adminAuthFrom(AdminAuthResult result) {
  return AdminAuth(
    status: switch (result.outcome) {
      AdminAuthOutcome.ok => AdminAuthStatus.ok,
      AdminAuthOutcome.invalid => AdminAuthStatus.invalid,
      AdminAuthOutcome.locked => AdminAuthStatus.locked,
      AdminAuthOutcome.offline => AdminAuthStatus.offline,
      AdminAuthOutcome.error => AdminAuthStatus.error,
    },
    retryAfterSec: result.retryAfterSec,
    attemptsLeft: result.attemptsLeft,
    message: result.message,
  );
}

SyncResult syncResultFrom(SyncOutcome outcome) {
  return SyncResult(ok: outcome.ok, atMs: outcome.atMs, errorCode: outcome.errorCode);
}
