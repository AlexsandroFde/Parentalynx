import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/config/app_config.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/network/network_providers.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/features/guardian/auth/presentation/app_lock.dart';
import 'package:parentalynx/features/guardian/auth/presentation/session_controller.dart';
import 'package:parentalynx/features/guardian/shell/data/local_prefs.dart';

import '../support/guardian_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;
  late NativeDoubles native;
  late FakeClock clock;
  late InMemorySecureStore store;

  ProviderContainer build({String? token, LocalPrefs? prefs}) {
    final ProviderContainer container = ProviderContainer(
      overrides: guardianOverrides(
        backend: backend,
        native: native,
        sessionToken: token,
        secureStore: store,
        clock: clock,
        prefs: prefs,
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  GuardianSessionController controllerOf(ProviderContainer container) {
    return container.read(guardianSessionProvider.notifier);
  }

  setUp(() {
    backend = FakeBackend();
    native = NativeDoubles();
    clock = FakeClock();
    store = InMemorySecureStore();
    backend.onJson('GET', '/v1/guardian/me', <String, Object?>{
      'guardian': guardianJson(),
      'session': sessionJson(),
    });
    backend.onJson('POST', '/v1/guardian/session/elevate', <String, Object?>{'elevatedUntil': 123});
  });

  test('sem token comeca sem sessao e com token comeca bloqueado', () {
    expect(build().read(guardianSessionProvider), isA<GuardianSignedOut>());
    expect(build(token: 'gs_x').read(guardianSessionProvider), isA<GuardianLocked>());
  });

  test('registro abre a sessao, grava o token e deixa a chave pendente', () async {
    backend.onJson('POST', '/v1/auth/register', authJson(recoveryKey: 'RK-AAAAA'), status: 201);
    final ProviderContainer container = build();

    await controllerOf(container).register(
      email: 'maria@exemplo.com',
      displayName: 'Maria Souza',
      password: 'Girassol-azul-42',
      deviceName: 'Galaxy da Maria',
    );

    final GuardianSession session = container.read(guardianSessionProvider);
    expect(session, isA<GuardianReady>());
    expect((session as GuardianReady).pendingRecoveryKey, 'RK-AAAAA');
    expect(container.read(sessionTokenProvider), 'gs_novo');
    expect(await store.read(StorageKeys.guardianSessionToken), 'gs_novo');
    expect(await store.read(StorageKeys.guardianEmail), 'maria@exemplo.com');
    expect(backend.lastBody('POST', '/v1/auth/register')['deviceName'], 'Galaxy da Maria');
    verify(() => native.guardian.enableAlertPolling('https://servidor.teste')).called(1);

    controllerOf(container).acknowledgeRecoveryKey();
    expect((container.read(guardianSessionProvider) as GuardianReady).pendingRecoveryKey, isNull);
  });

  test('login com credencial errada nao abre sessao', () async {
    backend.onError('POST', '/v1/auth/login', status: 401, code: 'invalid_credentials');
    final ProviderContainer container = build();

    await expectLater(
      controllerOf(container).login(email: 'a@b.co', password: 'x', deviceName: 'y'),
      throwsA(isA<ApiFailure>()),
    );

    expect(container.read(guardianSessionProvider), isA<GuardianSignedOut>());
    expect(container.read(sessionTokenProvider), isNull);
  });

  test('desbloqueio eleva a sessao e carrega a conta', () async {
    final ProviderContainer container = build(token: 'gs_x');

    await controllerOf(container).unlock('Girassol-azul-42');

    final GuardianSession session = container.read(guardianSessionProvider);
    expect(session, isA<GuardianReady>());
    expect((session as GuardianReady).account.displayName, 'Maria Souza');
    expect(backend.lastBody('POST', '/v1/guardian/session/elevate')['password'], isNotEmpty);
  });

  test('desbloqueio com senha errada mantem o painel bloqueado', () async {
    backend.onError(
      'POST',
      '/v1/guardian/session/elevate',
      status: 401,
      code: 'invalid_credentials',
    );
    final ProviderContainer container = build(token: 'gs_x');

    await expectLater(controllerOf(container).unlock('errada'), throwsA(isA<ApiFailure>()));

    expect(container.read(guardianSessionProvider), isA<GuardianLocked>());
    expect(container.read(sessionTokenProvider), 'gs_x');
  });

  group('bloqueio ao voltar do segundo plano', () {
    Future<ProviderContainer> ready({LocalPrefs? prefs}) async {
      final ProviderContainer container = build(token: 'gs_x', prefs: prefs);
      await controllerOf(container).unlock('Girassol-azul-42');
      // Deixa a preferencia de bloqueio carregar.
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    void background(ProviderContainer container, Duration away) {
      controllerOf(container).handleLifecycle(AppLifecycleState.hidden);
      controllerOf(container).handleLifecycle(AppLifecycleState.paused);
      clock.advance(away);
      controllerOf(container).handleLifecycle(AppLifecycleState.resumed);
    }

    test('bloqueia depois do tempo padrao de 1 minuto', () async {
      final ProviderContainer container = await ready();
      background(container, const Duration(seconds: 61));
      expect(container.read(guardianSessionProvider), isA<GuardianLocked>());
    });

    test('nao bloqueia antes do tempo', () async {
      final ProviderContainer container = await ready();
      background(container, const Duration(seconds: 30));
      expect(container.read(guardianSessionProvider), isA<GuardianReady>());
    });

    test('respeita o tempo escolhido nas preferencias', () async {
      final ProviderContainer container = await ready(
        prefs: InMemoryLocalPrefs(<String, Object>{LocalPrefKeys.appLockTimeoutSeconds: 0}),
      );
      expect(container.read(appLockTimeoutProvider), AppLockTimeout.immediately);
      background(container, const Duration(seconds: 1));
      expect(container.read(guardianSessionProvider), isA<GuardianLocked>());
    });

    test('perder o foco sem ir para o segundo plano nao bloqueia', () async {
      final ProviderContainer container = await ready();
      controllerOf(container).handleLifecycle(AppLifecycleState.inactive);
      clock.advance(const Duration(minutes: 30));
      controllerOf(container).handleLifecycle(AppLifecycleState.resumed);
      expect(container.read(guardianSessionProvider), isA<GuardianReady>());
    });

    test('nao bloqueia enquanto a chave de recuperacao nao foi confirmada', () async {
      backend.onJson('POST', '/v1/auth/register', authJson(recoveryKey: 'RK-AAAAA'), status: 201);
      final ProviderContainer container = build();
      await controllerOf(container).register(
        email: 'maria@exemplo.com',
        displayName: 'Maria',
        password: 'Girassol-azul-42',
        deviceName: 'x',
      );
      background(container, const Duration(minutes: 10));
      expect(container.read(guardianSessionProvider), isA<GuardianReady>());
    });
  });

  test('sessao recusada pelo servidor encerra a sessao local com aviso', () async {
    final ProviderContainer container = build(token: 'gs_x');
    await controllerOf(container).unlock('Girassol-azul-42');
    backend.onError('GET', '/v1/guardian/me', status: 401, code: 'session_expired');

    await controllerOf(container).refreshAccount();
    await Future<void>.delayed(Duration.zero);

    final GuardianSession session = container.read(guardianSessionProvider);
    expect(session, isA<GuardianSignedOut>());
    expect((session as GuardianSignedOut).notice, contains('encerrada'));
    expect(container.read(sessionTokenProvider), isNull);
    expect(await store.read(StorageKeys.guardianSessionToken), isNull);
    verify(native.guardian.disableAlertPolling).called(1);
  });

  test('sair encerra no servidor e limpa o aparelho, mesmo sem rede', () async {
    final ProviderContainer container = build(token: 'gs_x');
    await controllerOf(container).unlock('Girassol-azul-42');
    backend.on('POST', '/v1/auth/logout', (_) => throw const NetworkFailure());

    await controllerOf(container).signOut();

    expect(container.read(guardianSessionProvider), isA<GuardianSignedOut>());
    expect(container.read(sessionTokenProvider), isNull);
    expect(await store.read(StorageKeys.guardianEmail), isNull);
    verify(native.guardian.disableAlertPolling).called(1);
  });
}
