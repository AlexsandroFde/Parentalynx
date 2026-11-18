import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/core/utils/observable_value.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_entry.dart';
import 'package:parentalynx/features/app_management/domain/usecases/get_device_apps.dart';
import 'package:parentalynx/features/blocking/domain/usecases/lock_device_now.dart';
import 'package:parentalynx/features/blocking/domain/usecases/resume_rules.dart';
import 'package:parentalynx/features/blocking/domain/usecases/suspend_rules.dart';
import 'package:parentalynx/features/blocking/domain/usecases/unlock_device.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/child_device/domain/usecases/watch_child_devices.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/domain/entities/versioned_policy.dart';
import 'package:parentalynx/features/device_policy/domain/usecases/get_device_policy.dart';
import 'package:parentalynx/features/guardian/domain/entities/active_commands.dart';
import 'package:parentalynx/features/guardian/domain/entities/device_connection.dart';
import 'package:parentalynx/features/guardian/presentation/bloc/dashboard/guardian_dashboard_bloc.dart';
import 'package:parentalynx/features/guardian/presentation/bloc/dashboard/panel_state.dart';
import 'package:parentalynx/features/notifications/domain/entities/guardian_alert.dart';
import 'package:parentalynx/features/notifications/domain/usecases/get_recent_alerts.dart';
import 'package:parentalynx/features/notifications/domain/usecases/watch_incoming_alerts.dart';
import 'package:parentalynx/features/screen_time/domain/usecases/grant_additional_time.dart';

import '../../../support/fakes.dart';
import '../fixtures/dashboard_entities.dart';

class _MockWatchChildDevices extends Mock implements WatchChildDevices {}

class _MockGetDevicePolicy extends Mock implements GetDevicePolicy {}

class _MockGetDeviceApps extends Mock implements GetDeviceApps {}

class _MockGetRecentAlerts extends Mock implements GetRecentAlerts {}

class _MockWatchIncomingAlerts extends Mock implements WatchIncomingAlerts {}

class _MockGrantAdditionalTime extends Mock implements GrantAdditionalTime {}

class _MockLockDeviceNow extends Mock implements LockDeviceNow {}

class _MockUnlockDevice extends Mock implements UnlockDevice {}

class _MockSuspendRules extends Mock implements SuspendRules {}

class _MockResumeRules extends Mock implements ResumeRules {}

void main() {
  late _MockWatchChildDevices watchDevices;
  late _MockGetDevicePolicy getPolicy;
  late _MockGetDeviceApps getApps;
  late _MockGetRecentAlerts getRecentAlerts;
  late _MockWatchIncomingAlerts incomingAlerts;
  late _MockGrantAdditionalTime grantAdditionalTime;
  late _MockLockDeviceNow lockDeviceNow;
  late _MockUnlockDevice unlockDevice;
  late _MockSuspendRules suspendRules;
  late _MockResumeRules resumeRules;
  late ObservableValue<ChildDevice?> device;
  late StreamController<GuardianAlert> incoming;

  final ChildDevice joao = childDeviceOf(
    lastSyncAt: dashboardNowMs - minuteMs,
    snapshot: snapshotOf(quotaUsedMs: 70 * minuteMs, limitMs: 150 * minuteMs),
  );
  final VersionedPolicy policy = versionedPolicyOf();
  const DeviceApps apps = DeviceApps(day: dashboardToday, apps: <AppEntry>[]);
  final List<GuardianAlert> alerts = <GuardianAlert>[alertOf(3)];

  setUpAll(() {
    registerFallbackValue(<SuspensionScope>[]);
  });

  setUp(() {
    watchDevices = _MockWatchChildDevices();
    getPolicy = _MockGetDevicePolicy();
    getApps = _MockGetDeviceApps();
    getRecentAlerts = _MockGetRecentAlerts();
    incomingAlerts = _MockWatchIncomingAlerts();
    grantAdditionalTime = _MockGrantAdditionalTime();
    lockDeviceNow = _MockLockDeviceNow();
    unlockDevice = _MockUnlockDevice();
    suspendRules = _MockSuspendRules();
    resumeRules = _MockResumeRules();
    device = ObservableValue<ChildDevice?>.seeded(joao);
    incoming = StreamController<GuardianAlert>.broadcast();
    addTearDown(device.close);
    addTearDown(incoming.close);

    when(() => watchDevices.device(any())).thenAnswer((_) => device.stream);
    when(() => incomingAlerts()).thenAnswer((_) => incoming.stream);
    when(() => getPolicy(any())).thenAnswer((_) async => Ok<VersionedPolicy>(policy));
    when(() => getApps(any())).thenAnswer((_) async => const Ok<DeviceApps>(apps));
    when(() => getRecentAlerts()).thenAnswer((_) async => Ok<List<GuardianAlert>>(alerts));
  });

  GuardianDashboardBloc build() {
    return GuardianDashboardBloc(
      watchDevices: watchDevices,
      getDevicePolicy: getPolicy,
      getDeviceApps: getApps,
      getRecentAlerts: getRecentAlerts,
      incomingAlerts: incomingAlerts,
      grantAdditionalTime: grantAdditionalTime,
      lockDeviceNow: lockDeviceNow,
      unlockDevice: unlockDevice,
      suspendRules: suspendRules,
      resumeRules: resumeRules,
      clock: FakeClock(dashboardNow),
    );
  }

  /// Painel do aparelho em foco ja carregado.
  GuardianDashboardState loaded({
    ChildDevice? shown,
    VersionedPolicy? withPolicy,
    ActiveCommands commands = ActiveCommands.none,
    ActionStatus command = const ActionIdle(),
  }) {
    return GuardianDashboardState(
      deviceId: 'dev-1',
      device: shown ?? joao,
      connection: DeviceConnection.online,
      policy: PanelLoaded<VersionedPolicy>(withPolicy ?? policy),
      apps: const PanelLoaded<DeviceApps>(apps),
      recentAlerts: PanelLoaded<List<GuardianAlert>>(alerts),
      commands: commands,
      command: command,
    );
  }

  Future<void> select(GuardianDashboardBloc bloc) async {
    bloc.add(const DashboardDeviceSelected('dev-1'));
    await pumpEventQueue();
  }

  group('carga', () {
    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'o aparelho em foco carrega a politica, os apps e os alertas recentes',
      build: build,
      act: (GuardianDashboardBloc bloc) => bloc.add(const DashboardDeviceSelected('dev-1')),
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state, loaded());
        expect(bloc.state.isShowing('dev-1'), isTrue);
        expect(bloc.state.usage!.remainingMs, 80 * minuteMs);
        verify(() => getPolicy('dev-1')).called(1);
        verify(() => getApps('dev-1')).called(1);
        verify(() => getRecentAlerts()).called(1);
      },
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'primeira carga que falha mostra a falha so daquele cartao',
      setUp: () {
        when(() => getApps(any())).thenAnswer((_) async {
          return const Err<DeviceApps>(NetworkFailure());
        });
      },
      build: build,
      act: (GuardianDashboardBloc bloc) => bloc.add(const DashboardDeviceSelected('dev-1')),
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state.apps, const PanelFailed<DeviceApps>(NetworkFailure()));
        expect(bloc.state.policy, PanelLoaded<VersionedPolicy>(policy));
        expect(bloc.state.recentAlerts, PanelLoaded<List<GuardianAlert>>(alerts));
      },
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'atualizar mantem os dados anteriores quando a recarga falha e conclui o pedido',
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        when(() => getApps(any())).thenAnswer((_) async {
          return const Err<DeviceApps>(NetworkFailure());
        });
        final Completer<void> done = Completer<void>();
        bloc.add(DashboardRefreshRequested(completer: done));
        await done.future;
      },
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state, loaded());
        verify(() => getApps('dev-1')).called(2);
        verify(() => getRecentAlerts()).called(2);
      },
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'trocar de aparelho recomeca o painel com o aparelho novo',
      setUp: () {
        when(() => watchDevices.device('dev-2')).thenAnswer((_) {
          return Stream<ChildDevice?>.value(childDeviceOf(id: 'dev-2', childName: 'Ana'));
        });
      },
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        bloc.add(const DashboardDeviceSelected('dev-2'));
      },
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state.deviceId, 'dev-2');
        expect(bloc.state.device!.childName, 'Ana');
        expect(bloc.state.isShowing('dev-1'), isFalse);
        verify(() => getPolicy('dev-2')).called(1);
        verify(() => getApps('dev-2')).called(1);
      },
    );
  });

  group('acompanha o aparelho', () {
    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'uma sincronizacao nova recarrega os apps',
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        device.add(
          childDeviceOf(
            lastSyncAt: dashboardNowMs,
            snapshot: snapshotOf(quotaUsedMs: 75 * minuteMs, limitMs: 150 * minuteMs),
          ),
        );
      },
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state.device!.lastSyncAt, dashboardNowMs);
        verify(() => getApps('dev-1')).called(2);
        verify(() => getPolicy('dev-1')).called(1);
      },
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'versao nova da politica no servidor recarrega a politica e os comandos em vigor',
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        when(() => getPolicy(any())).thenAnswer((_) async {
          return Ok<VersionedPolicy>(
            versionedPolicyOf(
              version: 13,
              overrides: const PolicyOverrides(manualLock: ManualLock(active: true)),
            ),
          );
        });
        device.add(
          childDeviceOf(lastSyncAt: joao.lastSyncAt, policyVersion: 13, snapshot: joao.snapshot),
        );
      },
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state.policy.valueOrNull!.version, 13);
        expect(bloc.state.commands.paused, isTrue);
        verify(() => getPolicy('dev-1')).called(2);
      },
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'um alerta novo recarrega a previa de alertas recentes',
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        incoming.add(alertOf(9));
      },
      verify: (_) => verify(() => getRecentAlerts()).called(2),
    );
  });

  group('acoes rapidas', () {
    final VersionedPolicy withExtra = versionedPolicyOf(
      version: 13,
      overrides: const PolicyOverrides(
        extraTime: <ExtraTimeGrant>[
          ExtraTimeGrant(id: 'e1', day: dashboardToday, minutes: 30, grantedAt: 1),
        ],
      ),
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'tempo extra envia o comando, adota a politica devolvida e confirma',
      setUp: () {
        when(() => grantAdditionalTime(any(), minutes: any(named: 'minutes')))
            .thenAnswer((_) async {
              return Ok<VersionedPolicy>(withExtra);
            });
      },
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        bloc.add(const DashboardExtraTimeRequested(30));
      },
      skip: 5,
      expect: () => <GuardianDashboardState>[
        loaded(command: const ActionRunning()),
        loaded(
          withPolicy: withExtra,
          commands: const ActiveCommands(extraMinutesToday: 30),
          command: const ActionSucceeded(message: '30min a mais enviados para João.'),
        ),
      ],
      verify: (_) => verify(() => grantAdditionalTime('dev-1', minutes: 30)).called(1),
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'pausa sem prazo e retomada',
      setUp: () {
        when(() => lockDeviceNow(any(), duration: any(named: 'duration'))).thenAnswer((_) async {
          return Ok<VersionedPolicy>(
            versionedPolicyOf(
              version: 13,
              overrides: const PolicyOverrides(manualLock: ManualLock(active: true)),
            ),
          );
        });
        when(() => unlockDevice(any())).thenAnswer((_) async {
          return Ok<VersionedPolicy>(versionedPolicyOf(version: 14));
        });
      },
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        bloc.add(const DashboardPauseRequested());
        await pumpEventQueue();
        expect(bloc.state.commands.paused, isTrue);
        expect(bloc.state.command, const ActionSucceeded(message: 'Pausa enviada para João.'));
        bloc.add(const DashboardResumeRequested());
      },
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state.commands.paused, isFalse);
        expect(bloc.state.command, const ActionSucceeded(message: 'Retomada enviada para João.'));
        verify(() => lockDeviceNow('dev-1')).called(1);
        verify(() => unlockDevice('dev-1')).called(1);
      },
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'suspensao de regras e o fim da suspensao',
      setUp: () {
        when(
          () => suspendRules(
            any(),
            minutes: any(named: 'minutes'),
            scopes: any(named: 'scopes'),
          ),
        ).thenAnswer((_) async {
          return Ok<VersionedPolicy>(
            versionedPolicyOf(
              version: 13,
              overrides: PolicyOverrides(
                suspension: Suspension(
                  until: dashboardNowMs + 60 * minuteMs,
                  scopes: const <SuspensionScope>[SuspensionScope.dailyLimit],
                ),
              ),
            ),
          );
        });
        when(() => resumeRules(any())).thenAnswer((_) async {
          return Ok<VersionedPolicy>(versionedPolicyOf(version: 14));
        });
      },
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        bloc.add(
          const DashboardSuspendRequested(
            minutes: 60,
            scopes: <SuspensionScope>[SuspensionScope.dailyLimit],
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.commands.suspended, isTrue);
        expect(bloc.state.command, const ActionSucceeded(message: 'Regras suspensas por 1h.'));
        bloc.add(const DashboardSuspensionEndRequested());
      },
      verify: (GuardianDashboardBloc bloc) {
        expect(bloc.state.commands.suspended, isFalse);
        expect(
          bloc.state.command,
          const ActionSucceeded(message: 'As regras voltam a valer para João.'),
        );
        verify(
          () => suspendRules(
            'dev-1',
            minutes: 60,
            scopes: <SuspensionScope>[SuspensionScope.dailyLimit],
          ),
        ).called(1);
        verify(() => resumeRules('dev-1')).called(1);
      },
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'desistir do pedido de senha volta ao estado anterior sem aviso',
      setUp: () {
        when(() => grantAdditionalTime(any(), minutes: any(named: 'minutes')))
            .thenAnswer((_) async {
              return const Err<VersionedPolicy>(CancelledFailure());
            });
      },
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        bloc.add(const DashboardExtraTimeRequested(15));
      },
      skip: 5,
      expect: () => <GuardianDashboardState>[loaded(command: const ActionRunning()), loaded()],
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'comando recusado mostra a falha',
      setUp: () {
        when(() => unlockDevice(any())).thenAnswer((_) async {
          return const Err<VersionedPolicy>(NetworkFailure());
        });
      },
      build: build,
      act: (GuardianDashboardBloc bloc) async {
        await select(bloc);
        bloc.add(const DashboardResumeRequested());
      },
      skip: 5,
      expect: () => <GuardianDashboardState>[
        loaded(command: const ActionRunning()),
        loaded(command: const ActionFailed(NetworkFailure())),
      ],
    );

    blocTest<GuardianDashboardBloc, GuardianDashboardState>(
      'sem aparelho em foco os comandos nao fazem nada',
      build: build,
      act: (GuardianDashboardBloc bloc) => bloc.add(const DashboardExtraTimeRequested(15)),
      expect: () => const <GuardianDashboardState>[],
      verify: (_) => verifyNever(() => grantAdditionalTime(any(), minutes: any(named: 'minutes'))),
    );
  });
}
