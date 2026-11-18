// Aparelhos de exemplo no formato do protocolo (secao 4.1).

Map<String, Object?> deviceJson({
  String id = 'd1',
  String status = 'active',
  String childName = 'João',
  int policyVersion = 3,
  int appliedPolicyVersion = 3,
  Map<String, Object?>? state,
}) {
  return <String, Object?>{
    'id': id,
    'status': status,
    'childName': childName,
    'deviceName': 'Moto G de João',
    'model': 'moto g54',
    'manufacturer': 'motorola',
    'androidRelease': '14',
    'sdkInt': 34,
    'appVersion': '1.0.0',
    'timezone': 'America/Fortaleza',
    'createdAt': 1000,
    'approvedAt': 2000,
    'revokedAt': null,
    'lastSyncAt': 3000,
    'online': true,
    'today': '2026-11-17',
    'managementMode': 'device_owner',
    'policyVersion': policyVersion,
    'appliedPolicyVersion': appliedPolicyVersion,
    'policyAppliedAt': 2500,
    'pendingTimeRequests': 1,
    'state': state,
  };
}

const Map<String, Object?> stateJson = <String, Object?>{
  'reportedAt': 3000,
  'day': '2026-11-17',
  'quotaUsedMs': 5400000,
  'totalUsedMs': 6000000,
  'limitMs': 9000000,
  'extraMs': 0,
  'remainingMs': 3600000,
  'limitReachedAt': null,
  'permissions': <String, Object?>{
    'usageAccess': true,
    'accessibility': false,
    'overlay': false,
    'notifications': true,
    'batteryOptimizationIgnored': true,
    'deviceAdmin': true,
    'exactAlarms': true,
  },
  'enforcement': <String, Object?>{
    'active': true,
    'issues': <String>['accessibility_disabled'],
  },
  'lock': <String, Object?>{'state': 'schedule', 'releaseAt': 9999},
  'foregroundApp': 'com.whatsapp',
  'screenOn': true,
  'batteryPercent': 80,
  'clockTrusted': true,
};
