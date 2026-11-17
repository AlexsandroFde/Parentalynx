import 'dart:convert';

import 'package:flutter/widgets.dart' hide LockState;
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/network/network_providers.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/platform/native_providers.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/features/child/browser/presentation/browser_engine.dart';

import '../../../support/test_app.dart';

class MockChildAgentApi extends Mock implements ChildAgentApi {}

class MockDeviceApi extends Mock implements DeviceApi {}

class MockBrowserApi extends Mock implements BrowserApi {}

class MockAppModeApi extends Mock implements AppModeApi {}

/// Instante fixo usado nos testes: 17/11/2026 15:30 no fuso do aparelho.
final DateTime fakeNow = DateTime(2026, 11, 17, 15, 30);

int msAt(int hour, int minute, {int dayOffset = 0}) {
  return DateTime(2026, 11, 17 + dayOffset, hour, minute).millisecondsSinceEpoch;
}

void registerChildFallbacks() {
  registerFallbackValue(AppMode.unset);
  registerFallbackValue(
    ChildCredentials(
      serverUrl: '',
      deviceId: '',
      deviceToken: '',
      offlineSecret: '',
      childName: '',
      guardianName: '',
    ),
  );
}

PermissionSnapshot fakePermissions({
  bool usageAccess = true,
  bool accessibility = true,
  bool overlay = true,
  bool notifications = true,
  bool batteryOptimizationIgnored = true,
  bool deviceAdmin = false,
  bool deviceOwner = false,
  bool exactAlarms = true,
  bool restrictedSettingsLikely = false,
}) {
  return PermissionSnapshot(
    usageAccess: usageAccess,
    accessibility: accessibility,
    overlay: overlay,
    notifications: notifications,
    batteryOptimizationIgnored: batteryOptimizationIgnored,
    deviceAdmin: deviceAdmin,
    deviceOwner: deviceOwner,
    exactAlarms: exactAlarms,
    restrictedSettingsLikely: restrictedSettingsLikely,
  );
}

/// Retrato do agente com valores de um dia comum: 2h30 de limite, 1h10 usados.
AgentStatus fakeStatus({
  bool active = true,
  LockState lockState = LockState.none,
  int? releaseAtMs,
  String? activeScheduleLabel,
  bool limitEnabled = true,
  int limitMs = 9000000,
  int extraMs = 0,
  int quotaUsedMs = 4200000,
  int? remainingMs,
  int suspensionUntilMs = 0,
  List<String> suspensionScopes = const <String>[],
  int localOverrideUntilMs = 0,
  PermissionSnapshot? permissions,
  List<String> issues = const <String>[],
  bool clockTrusted = true,
  bool lastSyncOk = true,
  int? nextBlockAtMs,
  String? nextBlockLabel,
  ManagementMode managementMode = ManagementMode.standard,
  bool managedBrowserEnabled = true,
}) {
  return AgentStatus(
    active: active,
    childName: 'João',
    guardianName: 'Maria',
    managementMode: managementMode,
    lockState: lockState,
    releaseAtMs: releaseAtMs,
    activeScheduleLabel: activeScheduleLabel,
    limitEnabled: limitEnabled,
    limitMs: limitEnabled ? limitMs : 0,
    extraMs: extraMs,
    quotaUsedMs: quotaUsedMs,
    totalUsedMs: quotaUsedMs + 600000,
    remainingMs: remainingMs ?? (limitEnabled ? limitMs - quotaUsedMs : -1),
    day: '2026-11-17',
    nextResetAtMs: msAt(0, 0, dayOffset: 1),
    policyVersion: 3,
    lastSyncAtMs: msAt(15, 28),
    lastSyncOk: lastSyncOk,
    suspensionUntilMs: suspensionUntilMs,
    suspensionScopes: suspensionScopes,
    localOverrideUntilMs: localOverrideUntilMs,
    permissions: permissions ?? fakePermissions(),
    issues: issues,
    clockTrusted: clockTrusted,
    nowMs: fakeNow.millisecondsSinceEpoch,
    nextBlockAtMs: nextBlockAtMs,
    nextBlockLabel: nextBlockLabel,
    blockedAppsCount: 2,
    exceptionAppsCount: 2,
    managedBrowserEnabled: managedBrowserEnabled,
  );
}

const String fakePolicyJson = '''
{
  "schema": 1, "timezone": "America/Fortaleza",
  "dailyLimit": {"enabled": true, "minutes": 150, "resetTime": "00:00", "warnAtMinutes": [15, 5]},
  "allowedHours": {"enabled": false, "windows": []},
  "blockPeriods": [{"id": "p1", "label": "Hora de dormir", "enabled": true, "kind": "weekly",
    "days": [1, 2, 3, 4, 5, 6, 7], "start": "21:00", "end": "07:00"}],
  "apps": {"defaultForNewApps": "allowed", "rules": {
    "com.jogo": {"state": "blocked"}, "com.video": {"state": "blocked"},
    "com.whatsapp": {"state": "exception"}, "com.escola": {"state": "exception"}}},
  "web": {"managedBrowser": true, "mode": "blocklist"},
  "overrides": {"extraTime": [], "manualLock": {"active": false}, "suspension": {"until": 0, "scopes": []}}
}
''';

NativeDeviceInfo fakeDeviceInfo({String manufacturer = 'motorola'}) {
  return NativeDeviceInfo(
    name: 'Moto G de João',
    model: 'moto g54',
    manufacturer: manufacturer,
    androidRelease: '14',
    sdkInt: 34,
    appVersion: '1.0.0',
    timezone: 'America/Fortaleza',
    hardwareId: 'abc123',
  );
}

/// Dubles da ponte com respostas de um aparelho vinculado e sem problemas.
class ChildBridge {
  ChildBridge() {
    when(agent.getStatus).thenAnswer((_) async => status);
    when(agent.ensureRunning).thenAnswer((_) async {});
    when(agent.getPolicyJson).thenAnswer((_) async => fakePolicyJson);
    when(agent.getTodayUsage).thenAnswer(
      (_) async => <UsageEntry>[
        UsageEntry(packageName: 'com.video', label: 'Vídeos', ms: 2400000, opens: 4),
        UsageEntry(packageName: 'com.whatsapp', label: 'WhatsApp', ms: 1200000, opens: 9),
        UsageEntry(packageName: 'com.jogo', label: 'Jogo de Corrida', ms: 600000, opens: 2),
      ],
    );
    when(agent.getExceptionApps).thenAnswer(
      (_) async => <NativeAppInfo>[
        NativeAppInfo(
          packageName: 'com.whatsapp',
          label: 'WhatsApp',
          category: 'communication',
          system: false,
          essential: false,
        ),
        NativeAppInfo(
          packageName: 'com.escola',
          label: 'Escola Digital',
          category: 'other',
          system: false,
          essential: false,
        ),
      ],
    );
    when(agent.getTimeRequests).thenAnswer((_) async => requests);
    when(() => agent.getAppIcon(any())).thenAnswer((_) async => null);
    when(device.getDeviceInfo).thenAnswer((_) async => fakeDeviceInfo());
    when(device.getPermissions).thenAnswer((_) async => permissions);
  }

  final MockChildAgentApi agent = MockChildAgentApi();
  final MockDeviceApi device = MockDeviceApi();
  final MockAppModeApi mode = MockAppModeApi();
  AgentStatus status = fakeStatus();
  PermissionSnapshot permissions = fakePermissions();
  List<TimeRequestInfo> requests = <TimeRequestInfo>[];

  List<Override> overrides({
    AppMode appMode = AppMode.child,
    SecureStore? secureStore,
    http.Client? httpClient,
  }) {
    return <Override>[
      ...baseOverrides(mode: appMode, secureStore: secureStore),
      childAgentApiProvider.overrideWithValue(agent),
      deviceApiProvider.overrideWithValue(device),
      appModeApiProvider.overrideWithValue(mode),
      if (httpClient != null) httpClientProvider.overrideWithValue(httpClient),
    ];
  }
}

/// Resposta JSON para o cliente HTTP de teste.
http.Response jsonResponse(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response errorResponse(int status, String code, {Map<String, Object?>? details}) {
  return jsonResponse(<String, Object?>{
    'error': <String, Object?>{'code': code, 'message': 'Erro $code', 'details': ?details},
  }, status);
}

MockClient mockHttp(Future<http.Response> Function(http.Request request) handler) {
  return MockClient(handler);
}

/// Motor de paginas falso: registra o que foi pedido e mostra um quadro no lugar do WebView.
class FakeBrowserEngine implements BrowserEngine {
  final List<String> loaded = <String>[];
  BrowserEngineDelegate? delegate;
  bool back = false;
  bool forward = false;
  String? pageTitle;
  int reloads = 0;
  int backs = 0;

  @override
  void attach(BrowserEngineDelegate delegate) {
    this.delegate = delegate;
  }

  @override
  Widget buildView(BuildContext context) => const SizedBox.expand();

  @override
  Future<void> load(String url) async {
    loaded.add(url);
  }

  @override
  Future<void> reload() async {
    reloads += 1;
  }

  @override
  Future<void> goBack() async {
    backs += 1;
  }

  @override
  Future<void> goForward() async {}

  @override
  Future<bool> canGoBack() async => back;

  @override
  Future<bool> canGoForward() async => forward;

  @override
  Future<String?> title() async => pageTitle;
}
