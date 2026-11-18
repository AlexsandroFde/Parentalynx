import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/bloc/form_status.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/network/session_credentials.dart';
import 'package:parentalynx/features/authentication/domain/entities/credential_errors.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/auth/auth_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/login/login_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/register/register_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/unlock/unlock_bloc.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_dependencies.dart';

/// Fluxos de conta e sessao de ponta a ponta na camada de apresentacao: BLoCs reais, casos de
/// uso e repositorios reais, servidor falso.
void main() {
  late FakeBackend backend;

  TestDependencies build({String? token, InMemoryLocalPreferences? preferences}) {
    final TestDependencies deps = TestDependencies(
      backend: backend,
      sessionToken: token,
      preferences: preferences,
    );
    addTearDown(deps.dispose);
    return deps;
  }

  setUp(() {
    backend = FakeBackend()
      ..onJson('GET', '/v1/guardian/me', <String, Object?>{
        'guardian': guardianJson(),
        'session': sessionJson(),
      })
      ..onJson('POST', '/v1/guardian/session/elevate', <String, Object?>{'elevatedUntil': 123});
  });

  test('sem token comeca sem sessao e com token comeca bloqueado', () {
    expect(build().di<AuthBloc>().state, isA<AuthSignedOut>());
    expect(build(token: 'gs_x').di<AuthBloc>().state, isA<AuthLocked>());
  });

  test('criar conta abre a sessao, grava o token e deixa a chave pendente', () async {
    backend.onJson('POST', '/v1/auth/register', authJson(recoveryKey: 'RK-AAAAA'), status: 201);
    final TestDependencies deps = build();
    final AuthBloc auth = deps.di<AuthBloc>();
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

    final AuthState state = auth.state;
    expect(state, isA<AuthReady>());
    expect((state as AuthReady).pendingRecoveryKey, 'RK-AAAAA');
    expect(deps.di<SessionCredentials>().token, 'gs_novo');
    expect(deps.secureStore.values[StorageKeys.guardianSessionToken], 'gs_novo');
    expect(deps.secureStore.values[StorageKeys.guardianEmail], 'maria@exemplo.com');
    expect(backend.lastBody('POST', '/v1/auth/register')['deviceName'], 'Galaxy da Maria');

    auth.add(const AuthRecoveryKeyAcknowledged());
    await expectLater(
      auth.stream,
      emits(isA<AuthReady>().having((s) => s.pendingRecoveryKey, 'chave', isNull)),
    );
  });

  test('criar conta valida os campos antes de enviar', () async {
    final RegisterBloc register = build().di<RegisterBloc>();
    addTearDown(register.close);

    register.add(
      const RegisterSubmitted(
        displayName: ' ',
        email: 'nao-e-email',
        password: 'curta',
        confirmation: 'outra',
        deviceName: '',
      ),
    );
    final RegisterState state = await register.stream.first;

    expect(state.status, FormStatus.editing);
    expect(state.errors.name, 'Informe o seu nome.');
    expect(state.errors.email, 'Esse e-mail não parece válido.');
    expect(state.errors.password, isNotNull);
    expect(state.errors.confirmation, 'As senhas não são iguais.');
    expect(backend.requests, isEmpty);

    register.add(const RegisterFieldEdited(CredentialField.confirmation));
    expect((await register.stream.first).errors.confirmation, isNull);
  });

  blocTest<LoginBloc, LoginState>(
    'entrar com credencial errada mostra o aviso e nao abre sessao',
    setUp: () =>
        backend.onError('POST', '/v1/auth/login', status: 401, code: 'invalid_credentials'),
    build: () => build().di<LoginBloc>(),
    act: (LoginBloc bloc) =>
        bloc.add(const LoginSubmitted(email: 'a@b.co', password: 'Girassol-azul-42')),
    expect: () => <LoginState>[
      const LoginState(status: FormStatus.submitting),
      const LoginState(errors: CredentialErrors(form: 'E-mail ou senha incorretos.')),
    ],
  );

  test('desbloquear eleva a sessao e carrega a conta', () async {
    final TestDependencies deps = build(token: 'gs_x');
    final AuthBloc auth = deps.di<AuthBloc>();
    final UnlockBloc unlock = deps.di<UnlockBloc>();
    addTearDown(unlock.close);

    unlock.add(const UnlockSubmitted('Girassol-azul-42'));
    await expectLater(auth.stream, emitsThrough(isA<AuthReady>()));

    expect((auth.state as AuthReady).account.displayName, 'Maria Souza');
    expect(backend.lastBody('POST', '/v1/guardian/session/elevate')['password'], isNotEmpty);
  });

  test('desbloquear com senha errada mantem o painel bloqueado', () async {
    backend.onError(
      'POST',
      '/v1/guardian/session/elevate',
      status: 401,
      code: 'invalid_credentials',
    );
    final TestDependencies deps = build(token: 'gs_x');
    final UnlockBloc unlock = deps.di<UnlockBloc>();
    addTearDown(unlock.close);

    unlock.add(const UnlockSubmitted('errada'));
    await expectLater(
      unlock.stream,
      emitsThrough(isA<UnlockState>().having((s) => s.error, 'erro', 'Senha incorreta.')),
    );

    expect(deps.di<AuthBloc>().state, isA<AuthLocked>());
    expect(deps.di<SessionCredentials>().token, 'gs_x');
  });

  group('bloqueio ao voltar do segundo plano', () {
    Future<TestDependencies> ready({InMemoryLocalPreferences? preferences}) async {
      final TestDependencies deps = build(token: 'gs_x', preferences: preferences);
      final UnlockBloc unlock = deps.di<UnlockBloc>();
      addTearDown(unlock.close);
      unlock.add(const UnlockSubmitted('Girassol-azul-42'));
      await expectLater(deps.di<AuthBloc>().stream, emitsThrough(isA<AuthReady>()));
      return deps;
    }

    Future<void> background(TestDependencies deps, Duration away) async {
      final AuthBloc auth = deps.di<AuthBloc>()
        ..add(const AuthAppPaused())
        ..add(const AuthAppPaused());
      await pumpEventQueue();
      deps.clock.advance(away);
      auth.add(const AuthAppResumed());
      await pumpEventQueue();
    }

    test('bloqueia depois do tempo padrao de 1 minuto', () async {
      final TestDependencies deps = await ready();
      await background(deps, const Duration(seconds: 61));
      expect(deps.di<AuthBloc>().state, isA<AuthLocked>());
    });

    test('nao bloqueia antes do tempo', () async {
      final TestDependencies deps = await ready();
      await background(deps, const Duration(seconds: 30));
      expect(deps.di<AuthBloc>().state, isA<AuthReady>());
    });

    test('respeita o tempo escolhido nas preferencias', () async {
      final TestDependencies deps = await ready(
        preferences: InMemoryLocalPreferences(<String, Object>{
          LocalPrefKeys.appLockTimeoutSeconds: 0,
        }),
      );
      await background(deps, const Duration(seconds: 1));
      expect(deps.di<AuthBloc>().state, isA<AuthLocked>());
    });

    test('nao bloqueia enquanto a chave de recuperacao nao foi confirmada', () async {
      backend.onJson('POST', '/v1/auth/register', authJson(recoveryKey: 'RK-AAAAA'), status: 201);
      final TestDependencies deps = build();
      final RegisterBloc register = deps.di<RegisterBloc>();
      addTearDown(register.close);
      register.add(
        const RegisterSubmitted(
          displayName: 'Maria',
          email: 'maria@exemplo.com',
          password: 'Girassol-azul-42',
          confirmation: 'Girassol-azul-42',
          deviceName: 'x',
        ),
      );
      await expectLater(deps.di<AuthBloc>().stream, emitsThrough(isA<AuthReady>()));

      await background(deps, const Duration(minutes: 10));
      expect(deps.di<AuthBloc>().state, isA<AuthReady>());
    });
  });

  test('sessao recusada pelo servidor encerra a sessao local com aviso', () async {
    final TestDependencies deps = await () async {
      final TestDependencies deps = build(token: 'gs_x');
      final UnlockBloc unlock = deps.di<UnlockBloc>();
      addTearDown(unlock.close);
      unlock.add(const UnlockSubmitted('Girassol-azul-42'));
      await expectLater(deps.di<AuthBloc>().stream, emitsThrough(isA<AuthReady>()));
      return deps;
    }();
    backend.onError('GET', '/v1/guardian/me', status: 401, code: 'session_expired');

    final AuthBloc auth = deps.di<AuthBloc>()..add(const AuthAccountRefreshRequested());
    await expectLater(auth.stream, emitsThrough(isA<AuthSignedOut>()));

    expect((auth.state as AuthSignedOut).reason, SessionEndReason.expired);
    expect((auth.state as AuthSignedOut).notice, contains('encerrada'));
    expect(deps.di<SessionCredentials>().token, isNull);
    await pumpEventQueue();
    expect(deps.secureStore.values[StorageKeys.guardianSessionToken], isNull);
  });

  test('sair encerra no servidor e limpa o aparelho, mesmo sem rede', () async {
    final TestDependencies deps = build(token: 'gs_x');
    final UnlockBloc unlock = deps.di<UnlockBloc>();
    addTearDown(unlock.close);
    unlock.add(const UnlockSubmitted('Girassol-azul-42'));
    final AuthBloc auth = deps.di<AuthBloc>();
    await expectLater(auth.stream, emitsThrough(isA<AuthReady>()));
    backend.on('POST', '/v1/auth/logout', (_) => throw const NetworkFailure());

    auth.add(const AuthSignOutRequested());
    await expectLater(auth.stream, emitsThrough(isA<AuthSignedOut>()));
    await pumpEventQueue();

    expect((auth.state as AuthSignedOut).notice, isNull);
    expect(deps.di<SessionCredentials>().token, isNull);
    expect(deps.secureStore.values[StorageKeys.guardianEmail], isNull);
  });
}
