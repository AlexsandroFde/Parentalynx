// Exemplos de respostas da API no formato do protocolo, para os testes do modo responsavel.

/// Instante relativo ao relogio real, para os textos "ha N min" ficarem estaveis nas capturas.
int minutesAgo(int minutes) {
  return DateTime.now().subtract(Duration(minutes: minutes)).millisecondsSinceEpoch;
}

// Exemplos no formato do protocolo.

Map<String, Object?> guardianJson({String displayName = 'Maria Souza'}) {
  return <String, Object?>{
    'id': 'g1',
    'email': 'maria@exemplo.com',
    'displayName': displayName,
    'createdAt': 1,
    'settings': <String, Object?>{
      'retentionDays': 90,
      'syncStaleMinutes': 180,
      'offlineHours': 24,
      'lowTimeMinutes': 10,
    },
    'notificationPrefs': <String, Object?>{'limit_reached': true, 'low_time': false},
  };
}

Map<String, Object?> sessionJson({String? token}) {
  return <String, Object?>{
    'id': 's1',
    'deviceName': 'Galaxy da Maria',
    'createdAt': 1,
    'lastSeenAt': 2,
    'expiresAt': 99999999999999,
    'elevatedUntil': 99999999999999,
    'current': true,
    'token': ?token,
  };
}

Map<String, Object?> authJson({String? recoveryKey}) {
  return <String, Object?>{
    'guardian': guardianJson(),
    'session': sessionJson(token: 'gs_novo'),
    'recoveryKey': ?recoveryKey,
  };
}

Map<String, Object?> deviceJson({
  String id = 'd1',
  String status = 'active',
  String childName = 'João',
  String? confirmCode,
  bool relink = false,
  bool online = true,
  String managementMode = 'standard',
  int pendingTimeRequests = 0,
  int? createdAt,
  bool withState = true,
  List<String> issues = const <String>[],
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
    'confirmCode': ?confirmCode,
    'relink': relink,
    'createdAt': createdAt ?? minutesAgo(2),
    'approvedAt': status == 'active' ? 5 : null,
    'lastSyncAt': minutesAgo(1),
    'online': online,
    'today': '2026-11-17',
    'managementMode': managementMode,
    'policyVersion': 3,
    'appliedPolicyVersion': 3,
    'pendingTimeRequests': pendingTimeRequests,
    if (withState && status == 'active')
      'state': <String, Object?>{
        'reportedAt': minutesAgo(1),
        'day': '2026-11-17',
        'quotaUsedMs': 3600000,
        'totalUsedMs': 4000000,
        'limitMs': 9000000,
        'extraMs': 0,
        'remainingMs': 5400000,
        'lock': <String, Object?>{'state': 'none', 'releaseAt': null},
        'screenOn': true,
        'permissions': <String, Object?>{
          'usageAccess': true,
          'accessibility': issues.isEmpty,
          'overlay': false,
          'notifications': true,
          'batteryOptimizationIgnored': true,
          'deviceAdmin': false,
          'exactAlarms': true,
        },
        'enforcement': <String, Object?>{'active': true, 'issues': issues},
        'clockTrusted': true,
      },
  };
}

Map<String, Object?> alertJson({
  required int id,
  String type = 'limit_reached',
  String title = 'Limite diário atingido',
  String body = 'João usou as 2h30 de hoje.',
  bool read = false,
  int? createdAt,
}) {
  return <String, Object?>{
    'id': id,
    'type': type,
    'deviceId': 'd1',
    'childName': 'João',
    'createdAt': createdAt ?? minutesAgo(20),
    'readAt': read ? 10 : null,
    'notify': true,
    'title': title,
    'body': body,
    'data': <String, Object?>{},
  };
}
