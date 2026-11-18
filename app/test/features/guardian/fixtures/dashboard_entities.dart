import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/domain/entities/versioned_policy.dart';
import 'package:parentalynx/features/notifications/domain/entities/guardian_alert.dart';

// Entidades de exemplo do painel, sem JSON.

/// Momento dos exemplos: 17/11/2026, 15:30 (o mesmo do `FakeClock` padrao).
final DateTime dashboardNow = DateTime(2026, 11, 17, 15, 30);

int get dashboardNowMs => dashboardNow.millisecondsSinceEpoch;

const String dashboardToday = '2026-11-17';

const int minuteMs = 60000;

DeviceSnapshot snapshotOf({
  String day = dashboardToday,
  int quotaUsedMs = 0,
  int? totalUsedMs,
  int? limitMs,
  int? remainingMs,
  int extraMs = 0,
  int reportedAt = 1,
  DeviceLockState lockState = DeviceLockState.none,
}) {
  return DeviceSnapshot(
    reportedAt: reportedAt,
    day: day,
    quotaUsedMs: quotaUsedMs,
    totalUsedMs: totalUsedMs ?? quotaUsedMs,
    extraMs: extraMs,
    limitMs: limitMs,
    remainingMs: remainingMs,
    lockState: lockState,
    screenOn: true,
    permissions: DevicePermissions.unknown,
    enforcementActive: true,
    issues: const <String>[],
    clockTrusted: true,
  );
}

ChildDevice childDeviceOf({
  String id = 'dev-1',
  String childName = 'João',
  bool online = true,
  int? lastSyncAt,
  String today = dashboardToday,
  int policyVersion = 12,
  DeviceSnapshot? snapshot,
}) {
  return ChildDevice(
    id: id,
    status: DeviceLinkStatus.active,
    childName: childName,
    deviceName: 'Moto G de $childName',
    model: 'moto g54',
    manufacturer: 'motorola',
    androidRelease: '14',
    sdkInt: 34,
    appVersion: '1.0.0',
    timezone: 'America/Fortaleza',
    relink: false,
    createdAt: 1,
    online: online,
    today: today,
    managementMode: DeviceManagementMode.standard,
    policyVersion: policyVersion,
    appliedPolicyVersion: policyVersion,
    pendingTimeRequests: 0,
    lastSyncAt: lastSyncAt,
    snapshot: snapshot,
  );
}

VersionedPolicy versionedPolicyOf({
  int version = 12,
  PolicyOverrides overrides = const PolicyOverrides(),
}) {
  return VersionedPolicy(
    version: version,
    policy: Policy(timezone: 'America/Fortaleza', overrides: overrides),
  );
}

GuardianAlert alertOf(int id, {String title = 'Limite diário atingido'}) {
  return GuardianAlert(
    id: id,
    type: 'limit_reached',
    deviceId: 'dev-1',
    childName: 'João',
    createdAt: dashboardNowMs,
    notify: true,
    title: title,
    body: 'João usou as 2h30 de hoje.',
  );
}
