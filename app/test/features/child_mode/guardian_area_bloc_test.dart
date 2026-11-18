import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/platform/native_api.g.dart' hide AgentStatus;
import 'package:parentalynx/features/child_mode/presentation/bloc/guardian_area/guardian_area_bloc.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';
import 'package:parentalynx/features/user_role/domain/repositories/i_user_role_repository.dart';

import '../../support/test_dependencies.dart';
import 'support/child_fakes.dart';

AdminAuthResult _auth(AdminAuthOutcome outcome, {int retry = 0, int attempts = -1}) {
  return AdminAuthResult(outcome: outcome, retryAfterSec: retry, attemptsLeft: attempts);
}

void main() {
  late TestDependencies deps;
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() {
    (:deps, :bridge) = childDependencies();
    addTearDown(deps.dispose);
    deps.di<ILinkStateRepository>().update(const LinkState(LinkPhase.ready));
  });

  GuardianAreaBloc build() => deps.di<GuardianAreaBloc>();

  void acceptPassword(String password) {
    when(() => bridge.agent.verifyAdminPassword(password))
        .thenAnswer((_) async => _auth(AdminAuthOutcome.ok));
  }

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'senha correta libera a area',
    setUp: () => acceptPassword('Senha#Forte1'),
    build: build,
    act: (GuardianAreaBloc bloc) => bloc.add(const GuardianAreaPasswordSubmitted('Senha#Forte1')),
    expect: () => <GuardianAreaState>[
      const GuardianAreaLocked(verifying: true),
      const GuardianAreaUnlocked(),
    ],
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'senha vazia nem chega ao agente',
    build: build,
    act: (GuardianAreaBloc bloc) => bloc.add(const GuardianAreaPasswordSubmitted('')),
    expect: () => <GuardianAreaState>[
      const GuardianAreaLocked(verifying: true),
      const GuardianAreaLocked(error: 'Digite a senha administrativa.'),
    ],
    verify: (_) => verifyNever(() => bridge.agent.verifyAdminPassword(any())),
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'senha incorreta mostra as tentativas restantes',
    setUp: () {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.invalid, attempts: 2));
    },
    build: build,
    act: (GuardianAreaBloc bloc) => bloc.add(const GuardianAreaPasswordSubmitted('errada')),
    skip: 1,
    expect: () => <GuardianAreaState>[
      const GuardianAreaLocked(error: 'Senha incorreta. Restam 2 tentativas.'),
    ],
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'bloqueio por tentativas informa o tempo de espera',
    setUp: () {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.locked, retry: 600));
    },
    build: build,
    act: (GuardianAreaBloc bloc) => bloc.add(const GuardianAreaPasswordSubmitted('x')),
    verify: (GuardianAreaBloc bloc) {
      expect((bloc.state as GuardianAreaLocked).error, contains('10min'));
    },
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'sem conexao oferece o codigo de acesso offline',
    setUp: () {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.offline));
    },
    build: build,
    act: (GuardianAreaBloc bloc) => bloc.add(const GuardianAreaPasswordSubmitted('x')),
    verify: (GuardianAreaBloc bloc) {
      final GuardianAreaLocked state = bloc.state as GuardianAreaLocked;
      expect(state.codeMode, isTrue);
      expect(state.error, contains('código de acesso offline'));
    },
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'codigo offline valido libera a area',
    setUp: () {
      when(() => bridge.agent.verifyOfflineCode('12345678'))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.ok));
    },
    build: build,
    act: (GuardianAreaBloc bloc) async {
      bloc.add(const GuardianAreaCodeSubmitted('1234'));
      await pumpEventQueue();
      bloc.add(const GuardianAreaCodeSubmitted('1234 5678'));
    },
    expect: () => <GuardianAreaState>[
      const GuardianAreaLocked(codeMode: true, verifying: true),
      const GuardianAreaLocked(codeMode: true, error: 'O código tem 8 números.'),
      const GuardianAreaLocked(codeMode: true, verifying: true),
      const GuardianAreaUnlocked(codeMode: true),
    ],
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'erro inesperado da ponte vira mensagem sem detalhes tecnicos',
    setUp: () {
      when(() => bridge.agent.verifyAdminPassword(any())).thenThrow(
        PlatformException(code: 'NullPointerException', message: 'npe', details: 'Cause: null'),
      );
    },
    build: build,
    act: (GuardianAreaBloc bloc) => bloc.add(const GuardianAreaPasswordSubmitted('x')),
    verify: (GuardianAreaBloc bloc) {
      expect(
        (bloc.state as GuardianAreaLocked).error,
        'O aparelho não respondeu como esperado. Tente de novo.',
      );
    },
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'alternar entre senha e codigo limpa o erro',
    build: build,
    seed: () => const GuardianAreaLocked(error: 'Senha incorreta.'),
    act: (GuardianAreaBloc bloc) => bloc
      ..add(const GuardianAreaModeToggled())
      ..add(const GuardianAreaModeToggled()),
    expect: () => <GuardianAreaState>[
      const GuardianAreaLocked(codeMode: true),
      const GuardianAreaLocked(),
    ],
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'liberar o uso avisa por quanto tempo',
    setUp: () {
      acceptPassword('Senha#Forte1');
      when(() => bridge.agent.grantLocalOverride(30)).thenAnswer((_) async {});
    },
    build: build,
    act: (GuardianAreaBloc bloc) async {
      bloc.add(const GuardianAreaPasswordSubmitted('Senha#Forte1'));
      await pumpEventQueue();
      bloc.add(const GuardianAreaOverrideGranted(30));
    },
    skip: 2,
    expect: () => <GuardianAreaState>[
      const GuardianAreaUnlocked(running: GuardianOperation.grantOverride),
      const GuardianAreaUnlocked(action: ActionSucceeded(message: 'Uso liberado por 30min.')),
    ],
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'operacao recusada com acesso vencido volta a pedir a senha',
    setUp: () {
      acceptPassword('Senha#Forte1');
      when(() => bridge.agent.grantLocalOverride(30)).thenThrow(
        PlatformException(code: 'admin_auth_required', message: 'Autenticação necessária.'),
      );
    },
    build: build,
    act: (GuardianAreaBloc bloc) async {
      bloc.add(const GuardianAreaPasswordSubmitted('Senha#Forte1'));
      await pumpEventQueue();
      bloc.add(const GuardianAreaOverrideGranted(30));
    },
    verify: (GuardianAreaBloc bloc) {
      final GuardianAreaLocked state = bloc.state as GuardianAreaLocked;
      expect(state.error, contains('venceu'));
      verifyNever(() => bridge.agent.isAdminAuthValid());
    },
  );

  blocTest<GuardianAreaBloc, GuardianAreaState>(
    'outra falha da operacao fica na area e vira aviso',
    setUp: () {
      acceptPassword('Senha#Forte1');
      when(() => bridge.device.releaseDeviceOwner()).thenAnswer((_) async => false);
    },
    build: build,
    act: (GuardianAreaBloc bloc) async {
      bloc.add(const GuardianAreaPasswordSubmitted('Senha#Forte1'));
      await pumpEventQueue();
      bloc.add(const GuardianAreaOwnershipReleased());
    },
    verify: (GuardianAreaBloc bloc) {
      final GuardianAreaUnlocked state = bloc.state as GuardianAreaUnlocked;
      expect((state.action as ActionFailed).failure.message, contains('não aceitou'));
    },
  );

  test('desvincular revoga com a senha, marca sem vinculo e volta a escolha de modo', () async {
    acceptPassword('Senha#Forte1');
    when(() => bridge.agent.unlink('Senha#Forte1')).thenAnswer((_) async => true);
    final GuardianAreaBloc bloc = build();
    addTearDown(bloc.close);
    bloc.add(const GuardianAreaPasswordSubmitted('Senha#Forte1'));
    await pumpEventQueue();

    bloc.add(const GuardianAreaUnlinkRequested());
    await pumpEventQueue();

    verify(() => bridge.agent.unlink('Senha#Forte1')).called(1);
    verify(() => bridge.mode.setMode(AppMode.unset)).called(1);
    expect(deps.di<ILinkStateRepository>().current.phase, LinkPhase.unlinked);
    expect(deps.di<IUserRoleRepository>().current, UserRole.unset);
    expect((bloc.state as GuardianAreaUnlocked).action, isA<ActionSucceeded>());
  });

  test('desvincular com o codigo offline e local e nao envia senha', () async {
    when(() => bridge.agent.verifyOfflineCode('12345678'))
        .thenAnswer((_) async => _auth(AdminAuthOutcome.ok));
    when(() => bridge.agent.unlink(null)).thenAnswer((_) async => true);
    final GuardianAreaBloc bloc = build();
    addTearDown(bloc.close);
    bloc.add(const GuardianAreaCodeSubmitted('12345678'));
    await pumpEventQueue();

    bloc.add(const GuardianAreaUnlinkRequested());
    await pumpEventQueue();

    verify(() => bridge.agent.unlink(null)).called(1);
  });

  test('desvinculo recusado pelo agente fica na area com o aviso', () async {
    acceptPassword('Senha#Forte1');
    when(() => bridge.agent.unlink(any())).thenAnswer((_) async => false);
    final GuardianAreaBloc bloc = build();
    addTearDown(bloc.close);
    bloc.add(const GuardianAreaPasswordSubmitted('Senha#Forte1'));
    await pumpEventQueue();

    bloc.add(const GuardianAreaUnlinkRequested());
    await pumpEventQueue();

    final ActionStatus action = (bloc.state as GuardianAreaUnlocked).action;
    expect((action as ActionFailed).failure.message, contains('desvincular'));
    expect(deps.di<ILinkStateRepository>().current.phase, LinkPhase.ready);
    verifyNever(() => bridge.mode.setMode(any()));
  });

  test('sair da area pede a senha de novo na proxima visita', () async {
    acceptPassword('Senha#Forte1');
    final GuardianAreaBloc bloc = build();
    addTearDown(bloc.close);
    bloc.add(const GuardianAreaPasswordSubmitted('Senha#Forte1'));
    await pumpEventQueue();

    bloc.add(const GuardianAreaLeft());
    await pumpEventQueue();

    expect(bloc.state, const GuardianAreaLocked());
  });
}
