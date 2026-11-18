import '../../../../core/platform/native_api.g.dart' as native;
import '../../../device_policy/domain/entities/policy.dart';
import '../../domain/entities/agent_status.dart';
import '../../domain/entities/child_lock.dart';
import '../../domain/entities/management_level.dart';
import '../../domain/entities/permission_facts.dart';

/// Converte o retrato do agente gerado pelo Pigeon nas entidades do modo crianca.
abstract final class AgentStatusMapper {
  static AgentStatus status(native.AgentStatus status) {
    return AgentStatus(
      active: status.active,
      childName: status.childName,
      guardianName: status.guardianName,
      management: management(status.managementMode),
      lock: lock(status.lockState),
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
      suspensionScopes: List<SuspensionScope>.unmodifiable(
        status.suspensionScopes.map(suspensionScope).whereType<SuspensionScope>(),
      ),
      localOverrideUntilMs: status.localOverrideUntilMs,
      permissions: permissions(status.permissions),
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

  static PermissionFacts permissions(native.PermissionSnapshot snapshot) {
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

  static ManagementLevel management(native.ManagementMode mode) {
    return switch (mode) {
      native.ManagementMode.standard => ManagementLevel.standard,
      native.ManagementMode.deviceAdmin => ManagementLevel.deviceAdmin,
      native.ManagementMode.deviceOwner => ManagementLevel.deviceOwner,
    };
  }

  static ChildLock lock(native.LockState state) {
    return switch (state) {
      native.LockState.none => ChildLock.none,
      native.LockState.dailyLimit => ChildLock.dailyLimit,
      native.LockState.schedule => ChildLock.schedule,
      native.LockState.manualLock => ChildLock.manualLock,
      native.LockState.tamperLock => ChildLock.tamperLock,
    };
  }

  /// Escopo de suspensao pelo codigo do protocolo. Codigo desconhecido e ignorado.
  static SuspensionScope? suspensionScope(String code) {
    return switch (code) {
      'dailyLimit' => SuspensionScope.dailyLimit,
      'schedules' => SuspensionScope.schedules,
      'appBlocks' => SuspensionScope.appBlocks,
      _ => null,
    };
  }
}
