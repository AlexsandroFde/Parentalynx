import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart' as pigeon show AgentStatus;
import 'package:parentalynx/core/platform/native_api.g.dart' hide AgentStatus;
import 'package:parentalynx/features/app_management/app_management_child_module.dart';
import 'package:parentalynx/features/blocking/blocking_child_module.dart';
import 'package:parentalynx/features/child_mode/child_mode_module.dart';
import 'package:parentalynx/features/child_mode/data/mappers/agent_status_mapper.dart';
import 'package:parentalynx/features/child_mode/domain/entities/agent_status.dart';
import 'package:parentalynx/features/device_linking/device_linking_child_module.dart';
import 'package:parentalynx/features/managed_browser/managed_browser_module.dart';
import 'package:parentalynx/features/screen_time/screen_time_child_module.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/native_doubles.dart';
import '../../../support/test_dependencies.dart';

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

/// Retrato do agente (como chega da ponte) com valores de um dia comum: 2h30 de limite, 1h10
/// usados.
pigeon.AgentStatus fakeStatus({
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
  int policyVersion = 3,
}) {
  return pigeon.AgentStatus(
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
    policyVersion: policyVersion,
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

/// O mesmo retrato ja convertido para a entidade do modo crianca.
AgentStatus agentStatus(pigeon.AgentStatus status) => AgentStatusMapper.status(status);

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

/// Registra os modulos do modo crianca (e do navegador gerenciado) sobre o conteiner de
/// teste, que ja tem o nucleo e os modulos de base.
void registerChildModules(GetIt di) {
  registerDeviceLinkingChildModule(di);
  registerAppManagementChildModule(di);
  registerScreenTimeChildModule(di);
  registerBlockingChildModule(di);
  registerManagedBrowserModule(di);
  registerChildModeModule(di);
}

/// Respostas da ponte de um aparelho vinculado e sem problemas.
///
/// Os campos [status], [permissions] e [requests] podem ser trocados a qualquer momento: os
/// dubles leem o valor atual a cada chamada.
class ChildBridge {
  ChildBridge(this.native) {
    registerChildFallbacks();
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
    when(() => agent.activate(any(), any(), any())).thenAnswer((_) async {});
    when(device.getDeviceInfo).thenAnswer((_) async => fakeDeviceInfo());
    when(device.getPermissions).thenAnswer((_) async => permissions);
  }

  final NativeDoubles native;
  pigeon.AgentStatus status = fakeStatus();
  PermissionSnapshot permissions = fakePermissions();
  List<TimeRequestInfo> requests = <TimeRequestInfo>[];

  MockChildAgentApi get agent => native.agent;

  MockDeviceApi get device => native.device;

  MockAppModeApi get mode => native.mode;

  MockBrowserApi get browser => native.browser;
}

/// Conteiner de teste do aparelho da crianca: perfil crianca, ponte com as respostas de
/// [ChildBridge] e os modulos do modo crianca registrados. Descartado no fim do teste.
({TestDependencies deps, ChildBridge bridge}) childDependencies({
  FakeBackend? backend,
  InMemorySecureStore? secureStore,
  FakeLaunchActionSource? launchActions,
}) {
  final NativeDoubles native = NativeDoubles();
  final ChildBridge bridge = ChildBridge(native);
  final TestDependencies deps = TestDependencies(
    native: native,
    backend: backend,
    role: UserRole.child,
    secureStore: secureStore,
    launchActions: launchActions,
  );
  registerChildModules(deps.di);
  return (deps: deps, bridge: bridge);
}
