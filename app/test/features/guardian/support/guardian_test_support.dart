import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/network/network_providers.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/platform/native_providers.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/features/guardian/realtime/guardian_realtime.dart';
import 'package:parentalynx/features/guardian/shell/data/local_prefs.dart';
import 'package:parentalynx/features/guardian/shell/data/share_service.dart';

import '../../../support/test_app.dart';

class MockGuardianNativeApi extends Mock implements GuardianNativeApi {}

class MockDeviceApi extends Mock implements DeviceApi {}

class MockAppModeApi extends Mock implements AppModeApi {}

/// Servico de compartilhamento que so registra o que foi pedido.
class FakeShareService implements ShareService {
  final List<String> copied = <String>[];
  final List<String> shared = <String>[];
  final List<String> files = <String>[];

  @override
  Future<void> copy(String text) async => copied.add(text);

  @override
  Future<void> shareText(String text, {String? subject}) async => shared.add(text);

  @override
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async => files.add(fileName);
}

/// Relogio controlado pelo teste.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 11, 17, 15, 30);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

typedef BackendHandler = FutureOr<http.Response> Function(http.Request request);

/// Servidor de mentira: uma tabela de respostas por metodo e caminho, sobre o MockClient.
class FakeBackend {
  final Map<String, BackendHandler> _handlers = <String, BackendHandler>{};
  final List<http.Request> requests = <http.Request>[];

  /// Registra a resposta de `METODO /caminho` (sem a query).
  void on(String method, String path, BackendHandler handler) {
    _handlers['$method $path'] = handler;
  }

  /// Registra uma resposta JSON fixa.
  void onJson(String method, String path, Object body, {int status = 200}) {
    on(method, path, (http.Request request) => jsonResponse(body, status: status));
  }

  /// Registra uma resposta de erro no formato do protocolo.
  void onError(
    String method,
    String path, {
    required int status,
    required String code,
    String message = 'Erro.',
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    onJson(method, path, <String, Object?>{
      'error': <String, Object?>{'code': code, 'message': message, 'details': details},
    }, status: status);
  }

  http.Client get client => MockClient((http.Request request) async {
    requests.add(request);
    final BackendHandler? handler = _handlers['${request.method} ${request.url.path}'];
    if (handler == null) {
      return jsonResponse(<String, Object?>{
        'error': <String, Object?>{'code': 'not_found', 'message': 'Rota sem resposta no teste.'},
      }, status: 404);
    }
    return handler(request);
  });

  /// Requisicoes recebidas para `METODO /caminho`.
  List<http.Request> calls(String method, String path) {
    return requests.where((http.Request r) => r.method == method && r.url.path == path).toList();
  }

  /// Corpo JSON da ultima requisicao para `METODO /caminho`.
  Map<String, Object?> lastBody(String method, String path) {
    return jsonDecode(calls(method, path).last.body) as Map<String, Object?>;
  }
}

http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

/// Dubles da ponte nativa com respostas padrao.
class NativeDoubles {
  NativeDoubles({bool notificationsAllowed = true}) {
    registerFallbackValue(AppMode.unset);
    when(() => guardian.enableAlertPolling(any())).thenAnswer((_) async {});
    when(guardian.disableAlertPolling).thenAnswer((_) async {});
    when(() => guardian.setLastSeenAlertId(any())).thenAnswer((_) async {});
    when(guardian.getLastSeenAlertId).thenAnswer((_) async => 0);
    when(device.getDeviceInfo).thenAnswer(
      (_) async => NativeDeviceInfo(
        name: 'Galaxy da Maria',
        model: 'SM-A546',
        manufacturer: 'samsung',
        androidRelease: '15',
        sdkInt: 35,
        appVersion: '1.0.0',
        timezone: 'America/Fortaleza',
        hardwareId: 'abc',
      ),
    );
    when(device.getPermissions).thenAnswer(
      (_) async => PermissionSnapshot(
        usageAccess: false,
        accessibility: false,
        overlay: false,
        notifications: notificationsAllowed,
        batteryOptimizationIgnored: false,
        deviceAdmin: false,
        deviceOwner: false,
        exactAlarms: false,
        restrictedSettingsLikely: false,
      ),
    );
    when(device.requestNotificationPermission).thenAnswer((_) async => true);
    when(mode.consumeLaunchAction).thenAnswer((_) async => null);
    when(() => mode.setMode(any())).thenAnswer((_) async {});
  }

  final MockGuardianNativeApi guardian = MockGuardianNativeApi();
  final MockDeviceApi device = MockDeviceApi();
  final MockAppModeApi mode = MockAppModeApi();
}

/// Substituicoes para montar qualquer parte do modo responsavel sem rede e sem ponte nativa.
List<Override> guardianOverrides({
  required FakeBackend backend,
  required NativeDoubles native,
  String? sessionToken,
  SecureStore? secureStore,
  LocalPrefs? prefs,
  FakeClock? clock,
  ShareService? share,
  Stream<GuardianRealtimeEvent>? realtime,
}) {
  final FakeClock effectiveClock = clock ?? FakeClock();
  return <Override>[
    ...baseOverrides(mode: AppMode.guardian, sessionToken: sessionToken, secureStore: secureStore),
    httpClientProvider.overrideWithValue(backend.client),
    guardianNativeApiProvider.overrideWithValue(native.guardian),
    deviceApiProvider.overrideWithValue(native.device),
    appModeApiProvider.overrideWithValue(native.mode),
    localPrefsProvider.overrideWithValue(
      prefs ?? InMemoryLocalPrefs(<String, Object>{LocalPrefKeys.notificationsPrompted: true}),
    ),
    guardianClockProvider.overrideWithValue(effectiveClock.call),
    shareServiceProvider.overrideWithValue(share ?? FakeShareService()),
    // Sem WebSocket real nos testes.
    guardianRealtimeClientProvider.overrideWithValue(null),
    guardianRealtimeEventsProvider.overrideWith(
      (ref) => realtime ?? const Stream<GuardianRealtimeEvent>.empty(),
    ),
  ];
}

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
