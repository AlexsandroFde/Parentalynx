import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/form_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/domain/usecases/watch_guardian_session.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/auth/auth_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/register/register_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/unlock/unlock_bloc.dart';
import 'package:parentalynx/features/notifications/domain/services/alert_polling_coordinator.dart';
import 'package:parentalynx/features/notifications/domain/services/i_alert_polling_service.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_dependencies.dart';

class _MockWatchGuardianSession extends Mock implements WatchGuardianSession {}

class _MockAlertPollingService extends Mock implements IAlertPollingService {}

const SessionOpen _open = SessionOpen(
  account: GuardianAccount(
    id: 'g1',
    email: 'maria@exemplo.com',
    displayName: 'Maria Souza',
    createdAt: 1,
  ),
  session: GuardianSessionInfo(
    id: 's1',
    deviceName: 'Galaxy da Maria',
    createdAt: 1,
    lastSeenAt: 2,
    expiresAt: 3,
    elevatedUntil: 0,
    current: true,
  ),
);

void main() {
  group('AlertPollingCoordinator', () {
    late StreamController<GuardianSessionState> session;
    late _MockAlertPollingService polling;
    late AlertPollingCoordinator coordinator;

    setUp(() {
      session = StreamController<GuardianSessionState>();
      polling = _MockAlertPollingService();
      when(polling.enable).thenAnswer((_) async {});
      when(polling.disable).thenAnswer((_) async {});
      final _MockWatchGuardianSession watch = _MockWatchGuardianSession();
      when(watch.call).thenAnswer((_) => session.stream);
      coordinator = AlertPollingCoordinator(session: watch, polling: polling)..start();
      addTearDown(coordinator.stop);
    });

    tearDown(() {
      unawaited(session.close());
    });

    Future<void> emit(GuardianSessionState state) async {
      session.add(state);
      await pumpEventQueue();
    }

    test('o estado inicial nao muda a busca, que o lado nativo ja guarda', () async {
      await emit(_open);

      verifyNever(polling.enable);
      verifyNever(polling.disable);
    });

    test('abrir a sessao liga a busca uma vez', () async {
      await emit(const SessionLocked());
      await emit(_open);
      await emit(_open.withAccount(_open.account.copyWith(displayName: 'Maria S.')));

      verify(polling.enable).called(1);
      verifyNever(polling.disable);
    });

    test('bloquear o painel nao desliga a busca', () async {
      await emit(_open);
      await emit(const SessionLocked());

      verifyNever(polling.disable);
    });

    test('encerrar a sessao desliga a busca', () async {
      await emit(_open);
      await emit(const SessionSignedOut(reason: SessionEndReason.expired));
      await emit(const SessionSignedOut());

      verify(polling.disable).called(1);
    });

    test('start repetido nao assina duas vezes e stop encerra', () async {
      coordinator.start();
      expect(coordinator.isRunning, isTrue);

      await coordinator.stop();

      expect(coordinator.isRunning, isFalse);
      expect(session.hasListener, isFalse);
    });
  });

  // Fluxos reais de conta (autenticacao, casos de uso e repositorios), com o coordenador
  // registrado como no app.
  group('busca de alertas acompanha a sessao', () {
    late FakeBackend backend;

    TestDependencies build({String? token}) {
      final TestDependencies deps = TestDependencies(backend: backend, sessionToken: token);
      addTearDown(deps.dispose);
      registerNotificationsModule(deps.di);
      deps.di<AlertPollingCoordinator>().start();
      return deps;
    }

    Future<AuthBloc> unlocked(TestDependencies deps) async {
      final UnlockBloc unlock = deps.di<UnlockBloc>();
      addTearDown(unlock.close);
      final AuthBloc auth = deps.di<AuthBloc>();
      unlock.add(const UnlockSubmitted('Girassol-azul-42'));
      await expectLater(auth.stream, emitsThrough(isA<AuthReady>()));
      return auth;
    }

    setUp(() {
      backend = FakeBackend()
        ..onJson('GET', '/v1/guardian/me', <String, Object?>{
          'guardian': guardianJson(),
          'session': sessionJson(),
        })
        ..onJson('POST', '/v1/guardian/session/elevate', <String, Object?>{'elevatedUntil': 123});
    });

    test('criar conta liga a busca com o endereco do servidor', () async {
      backend.onJson('POST', '/v1/auth/register', authJson(recoveryKey: 'RK-AAAAA'), status: 201);
      final TestDependencies deps = build();
      final RegisterBloc register = deps.di<RegisterBloc>();
      addTearDown(register.close);

      register.add(
        const RegisterSubmitted(
          displayName: 'Maria Souza',
          email: 'maria@exemplo.com',
          password: 'Girassol-azul-42',
          confirmation: 'Girassol-azul-42',
          deviceName: 'Galaxy da Maria',
        ),
      );
      await expectLater(
        register.stream,
        emitsThrough(isA<RegisterState>().having((s) => s.status, 'status', FormStatus.succeeded)),
      );
      await pumpEventQueue();

      verify(() => deps.native.guardian.enableAlertPolling('https://servidor.teste')).called(1);
    });

    test('sessao recusada pelo servidor desliga a busca', () async {
      final TestDependencies deps = build(token: 'gs_x');
      final AuthBloc auth = await unlocked(deps);
      backend.onError('GET', '/v1/guardian/me', status: 401, code: 'session_expired');

      auth.add(const AuthAccountRefreshRequested());
      await expectLater(auth.stream, emitsThrough(isA<AuthSignedOut>()));
      await pumpEventQueue();

      verify(deps.native.guardian.disableAlertPolling).called(1);
    });

    test('sair desliga a busca, mesmo sem rede', () async {
      final TestDependencies deps = build(token: 'gs_x');
      final AuthBloc auth = await unlocked(deps);
      backend.on('POST', '/v1/auth/logout', (_) => throw const NetworkFailure());

      auth.add(const AuthSignOutRequested());
      await expectLater(auth.stream, emitsThrough(isA<AuthSignedOut>()));
      await pumpEventQueue();

      verify(deps.native.guardian.disableAlertPolling).called(1);
    });
  });
}
