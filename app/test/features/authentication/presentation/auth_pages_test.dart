import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/domain/repositories/i_session_repository.dart';
import 'package:parentalynx/features/authentication/domain/services/i_elevation_prompter.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/auth/auth_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/guardian_entry/guardian_entry_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/login/login_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/recover_access/recover_access_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/register/register_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/unlock/unlock_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/pages/login_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/recover_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/recovery_key_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/register_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/sign_in_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/unlock_page.dart';
import 'package:parentalynx/features/server_config/presentation/bloc/server_config_bloc.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

/// Tela alta para a fonte 2x: todo o conteudo e montado e conferido.
const Size _tallPhone = Size(392, 3200);

/// Telas de conta do responsavel montadas com os BLoCs reais e o servidor falso.
void main() {
  late FakeBackend backend;

  TestDependencies build({String? token, InMemorySecureStore? store}) {
    final TestDependencies deps = TestDependencies(
      backend: backend,
      sessionToken: token,
      secureStore: store,
    );
    addTearDown(deps.dispose);
    return deps;
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  setUp(() => backend = FakeBackend());

  /// Capturas clara e escura, fonte 2x sem erros e diretrizes de acessibilidade de uma tela.
  void screenChecks(
    String name,
    String screenshot,
    _Pump pump, {
    TestDependencies Function()? deps,
  }) {
    TestDependencies make() => deps?.call() ?? build();

    testWidgets('$name: captura no tema claro', tags: 'screenshot', (WidgetTester tester) async {
      await pump(tester, make());
      await settle(tester);
      await expectScreenshot(tester, screenshot);
    });

    testWidgets('$name: captura no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
      await pump(tester, make(), brightness: Brightness.dark);
      await settle(tester);
      await expectScreenshot(tester, '${screenshot}_escuro');
    });

    testWidgets('$name: funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      await pump(tester, make(), textScale: 2, size: _tallPhone);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pump(tester, make(), size: _tallPhone);
      await settle(tester);
      await expectAccessible(tester);
    });
  }

  // Porta de entrada.

  Future<void> pumpSignIn(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) {
    return pumpWidgetInApp(
      tester,
      MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<AuthBloc>.value(value: deps.di<AuthBloc>()),
          BlocProvider<GuardianEntryBloc>(
            create: (BuildContext context) =>
                deps.di<GuardianEntryBloc>()..add(const GuardianEntryStarted()),
          ),
          BlocProvider<ServerConfigBloc>(
            create: (BuildContext context) => deps.di<ServerConfigBloc>(),
          ),
        ],
        child: const SignInPage(),
      ),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  testWidgets('porta de entrada mostra os caminhos, o servidor e a troca de papel', (
    WidgetTester tester,
  ) async {
    await pumpSignIn(tester, build());
    await settle(tester);

    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
    expect(find.text('Como começar'), findsOneWidget);
    expect(find.text('https://servidor.teste'), findsOneWidget);
    expect(find.text('Trocar o papel deste aparelho'), findsOneWidget);

    // O servidor pode ser corrigido daqui, sem voltar para a escolha do papel.
    await tester.ensureVisible(find.text('https://servidor.teste'));
    await tester.tap(find.text('https://servidor.teste'));
    await settle(tester);
    expect(find.text('Salvar'), findsOneWidget);
  });

  screenChecks('porta de entrada', 'guardian_sign_in', pumpSignIn);

  // Criar conta.

  Future<void> pumpRegister(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) {
    return pumpWidgetInApp(
      tester,
      BlocProvider<RegisterBloc>(
        create: (BuildContext context) => deps.di<RegisterBloc>()..add(const RegisterStarted()),
        child: const RegisterPage(),
      ),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  testWidgets('registro valida a senha antes de enviar', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpRegister(tester, build());
    await settle(tester);
    final Finder fields = find.byType(TextField);
    // O nome do aparelho vem preenchido pelo sistema.
    expect(find.text('Galaxy da Maria'), findsOneWidget);
    // Os requisitos da senha aparecem antes de digitar.
    expect(find.text('Pelo menos 10 caracteres'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Maria Souza');
    await tester.enterText(fields.at(1), 'maria@exemplo.com');
    await tester.enterText(fields.at(2), 'curta1');
    await tester.enterText(fields.at(3), 'outra');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await settle(tester);

    expect(find.text('Use pelo menos 10 caracteres.'), findsOneWidget);
    expect(find.text('As senhas não são iguais.'), findsOneWidget);
    expect(backend.calls('POST', '/v1/auth/register'), isEmpty);

    await tester.enterText(fields.at(2), 'Girassol-azul-42');
    await tester.enterText(fields.at(3), 'Girassol-azul-42');
    await settle(tester);
    // Ao voltar a digitar, o erro do campo some.
    expect(find.text('As senhas não são iguais.'), findsNothing);
    await tester.ensureVisible(find.textContaining('Força da senha:'));
    await settle(tester);
    expect(find.text('Força da senha: Forte'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_register');
  });

  testWidgets('registro: o proximo do teclado passa da senha para a confirmacao', (
    WidgetTester tester,
  ) async {
    await pumpRegister(tester, build());
    await settle(tester);

    await tester.tap(find.byType(TextField).at(2));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    // Sem o ajuste, o foco pararia no botao de mostrar a senha e o teclado fecharia.
    final EditableText confirmation = tester.widget(find.byType(EditableText).at(3));
    expect(confirmation.focusNode.hasFocus, isTrue);
  });

  testWidgets('registro mostra o erro de e-mail ja usado no campo', (WidgetTester tester) async {
    backend.onError('POST', '/v1/auth/register', status: 409, code: 'email_in_use');
    await pumpRegister(tester, build());
    await settle(tester);
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Maria Souza');
    await tester.enterText(fields.at(1), 'maria@exemplo.com');
    await tester.enterText(fields.at(2), 'Girassol-azul-42');
    await tester.enterText(fields.at(3), 'Girassol-azul-42');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await settle(tester);

    expect(find.textContaining('Já existe uma conta com este e-mail'), findsOneWidget);
  });

  testWidgets('registro: tema escuro', tags: 'screenshot', (WidgetTester tester) async {
    await pumpRegister(tester, build(), brightness: Brightness.dark);
    await settle(tester);
    await expectScreenshot(tester, 'guardian_register_escuro');
  });

  testWidgets('registro funciona com a fonte no maior tamanho', (WidgetTester tester) async {
    await pumpRegister(tester, build(), textScale: 2, size: _tallPhone);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registro segue as diretrizes de acessibilidade', (WidgetTester tester) async {
    await pumpRegister(tester, build(), size: _tallPhone);
    await settle(tester);
    await expectAccessible(tester);
  });

  // Entrar.

  Future<void> pumpLogin(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) {
    return pumpWidgetInApp(
      tester,
      BlocProvider<LoginBloc>(
        create: (BuildContext context) => deps.di<LoginBloc>(),
        child: const LoginPage(),
      ),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  testWidgets('login mostra bloqueio por tentativas com o tempo de espera', (
    WidgetTester tester,
  ) async {
    backend.onError(
      'POST',
      '/v1/auth/login',
      status: 423,
      code: 'account_locked',
      details: <String, Object?>{'retryAfterSec': 120},
    );
    await pumpLogin(tester, build());
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'maria@exemplo.com');
    await tester.enterText(find.byType(TextField).at(1), 'qualquer');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await settle(tester);

    expect(find.text('Não foi possível entrar'), findsOneWidget);
    expect(find.text('Muitas tentativas. Tente de novo em 2 minutos.'), findsOneWidget);
  });

  screenChecks('entrar', 'guardian_login', pumpLogin);

  // Recuperar acesso.

  Future<void> pumpRecover(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) {
    return pumpWidgetInApp(
      tester,
      BlocProvider<RecoverAccessBloc>(
        create: (BuildContext context) =>
            deps.di<RecoverAccessBloc>()..add(const RecoverAccessStarted()),
        child: const RecoverPage(),
      ),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  testWidgets('recuperacao recusada diz o motivo e que a senha anterior continua', (
    WidgetTester tester,
  ) async {
    backend.onError('POST', '/v1/auth/recover', status: 401, code: 'invalid_credentials');
    await pumpRecover(tester, build());
    await settle(tester);
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'maria@exemplo.com');
    await tester.enterText(fields.at(1), 'rk-aaaaa-bbbbb-ccccc-ddddd-eeeee');
    await tester.enterText(fields.at(2), 'Girassol-azul-42');
    await tester.enterText(fields.at(3), 'Girassol-azul-42');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Recuperar acesso'));
    await tester.tap(find.widgetWithText(FilledButton, 'Recuperar acesso'));
    await settle(tester);

    expect(find.text('Não foi possível recuperar o acesso'), findsOneWidget);
    expect(
      find.text('E-mail ou chave de recuperação incorretos. A senha anterior continua valendo.'),
      findsOneWidget,
    );
  });

  screenChecks('recuperar acesso', 'guardian_recover', pumpRecover);

  // Chave de recuperacao.

  /// Abre a sessao com uma chave de recuperacao pendente, como depois de criar a conta.
  Future<TestDependencies> withPendingKey() async {
    final TestDependencies deps = build();
    await deps.di<ISessionRepository>().open(
      const AuthenticatedSession(
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
          expiresAt: 99999999999999,
          elevatedUntil: 99999999999999,
          current: true,
        ),
        token: 'gs_novo',
        recoveryKey: 'RK-7H2KD-9QWXA-4MNP8-TZ5VB-C3RGE',
      ),
    );
    return deps;
  }

  Future<void> pumpRecoveryKey(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) {
    return pumpWidgetInApp(
      tester,
      BlocProvider<AuthBloc>.value(value: deps.di<AuthBloc>(), child: const RecoveryKeyPage()),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  testWidgets('chave de recuperacao: copiar e confirmar', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = await tester.runAsync(withPendingKey) as TestDependencies;
    await pumpRecoveryKey(tester, deps);
    await settle(tester);

    await tester.tap(find.text('Copiar'));
    await settle(tester);
    expect(deps.share.copied.single, 'RK-7H2KD-9QWXA-4MNP8-TZ5VB-C3RGE');
    expect(find.text('Chave copiada.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await expectScreenshot(tester, 'guardian_recovery_key');

    // Sem a confirmacao, continuar fica inativo e a linha da confirmacao explica por que.
    final FilledButton proceed = tester.widget(find.widgetWithText(FilledButton, 'Continuar'));
    expect(proceed.onPressed, isNull);
    expect(find.textContaining('Necessário para continuar.'), findsOneWidget);

    await tester.tap(find.text('Guardei a chave em um lugar seguro'));
    await settle(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await settle(tester);
    final AuthState state = deps.di<AuthBloc>().state;
    expect(state, isA<AuthReady>());
    expect((state as AuthReady).pendingRecoveryKey, isNull);
  });

  testWidgets('chave de recuperacao: tema escuro', tags: 'screenshot', (WidgetTester tester) async {
    final TestDependencies deps = await tester.runAsync(withPendingKey) as TestDependencies;
    await pumpRecoveryKey(tester, deps, brightness: Brightness.dark);
    await settle(tester);
    await expectScreenshot(tester, 'guardian_recovery_key_escuro');
  });

  testWidgets('chave de recuperacao funciona com a fonte no maior tamanho', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = await tester.runAsync(withPendingKey) as TestDependencies;
    await pumpRecoveryKey(tester, deps, textScale: 2, size: _tallPhone);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chave de recuperacao segue as diretrizes de acessibilidade', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = await tester.runAsync(withPendingKey) as TestDependencies;
    await pumpRecoveryKey(tester, deps, size: _tallPhone);
    await settle(tester);
    await expectAccessible(tester);
    // O leitor de tela soletra a chave em grupos.
    expect(find.bySemanticsLabel(RegExp('Chave de recuperação: R K, 7 H 2 K D')), findsOneWidget);
  });

  // Painel bloqueado.

  TestDependencies lockedDeps() {
    return build(
      token: 'gs_x',
      store: InMemorySecureStore(<String, String>{StorageKeys.guardianEmail: 'maria@exemplo.com'}),
    );
  }

  Future<void> pumpUnlock(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) {
    return pumpWidgetInApp(
      tester,
      MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<AuthBloc>.value(value: deps.di<AuthBloc>()),
          BlocProvider<UnlockBloc>(
            create: (BuildContext context) => deps.di<UnlockBloc>()..add(const UnlockStarted()),
          ),
        ],
        child: const UnlockPage(),
      ),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  testWidgets('tela de bloqueio mostra a conta gravada', (WidgetTester tester) async {
    await pumpUnlock(tester, lockedDeps());
    await settle(tester);

    expect(find.text('Painel bloqueado'), findsOneWidget);
    expect(find.textContaining('maria@exemplo.com'), findsOneWidget);
    expect(find.text('Esqueci a senha'), findsOneWidget);
  });

  testWidgets('tela de bloqueio: entrar com outra conta pede confirmacao e sai da conta', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = lockedDeps();
    await pumpUnlock(tester, deps);
    await settle(tester);

    await tester.ensureVisible(find.text('Entrar com outra conta'));
    await tester.tap(find.text('Entrar com outra conta'));
    await settle(tester);
    expect(find.text('Entrar com outra conta?'), findsOneWidget);
    expect(find.textContaining('Este aparelho sai da conta maria@exemplo.com'), findsOneWidget);
    expect(deps.di<AuthBloc>().state, isA<AuthLocked>());

    await tester.tap(find.widgetWithText(FilledButton, 'Sair da conta'));
    await settle(tester);
    expect(deps.di<AuthBloc>().state, const AuthSignedOut(reason: SessionEndReason.signedOut));
  });

  screenChecks('painel bloqueado', 'guardian_unlock', pumpUnlock, deps: lockedDeps);

  // Pedido de senha para operacoes administrativas.

  Future<Future<bool>> openElevation(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) async {
    await pumpWidgetInApp(
      tester,
      const Scaffold(body: SizedBox.expand()),
      di: deps.di,
      navigatorKey: deps.navigatorKey,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
    final Future<bool> result = deps.di<IElevationPrompter>().requestElevation();
    await settle(tester);
    return result;
  }

  testWidgets('pedido de senha: recusa no campo e libera com a senha certa', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    backend.onError(
      'POST',
      '/v1/guardian/session/elevate',
      status: 401,
      code: 'invalid_credentials',
    );
    final TestDependencies deps = build(token: 'gs_x');
    final Future<bool> result = await openElevation(tester, deps);
    expect(find.text('Confirme sua senha'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await settle(tester);
    expect(find.text('Digite a senha administrativa.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await settle(tester);
    expect(find.text('Senha incorreta.'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_elevation');

    backend.onJson('POST', '/v1/guardian/session/elevate', <String, Object?>{'elevatedUntil': 123});
    await tester.enterText(find.byType(TextField), 'Girassol-azul-42');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await settle(tester);
    expect(find.text('Confirme sua senha'), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('pedido de senha: cancelar nao libera a operacao', (WidgetTester tester) async {
    final Future<bool> result = await openElevation(tester, build(token: 'gs_x'));
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(await result, isFalse);
  });

  testWidgets('pedido de senha: tema escuro', tags: 'screenshot', (WidgetTester tester) async {
    await openElevation(tester, build(token: 'gs_x'), brightness: Brightness.dark);
    await expectScreenshot(tester, 'guardian_elevation_escuro');
  });

  testWidgets('pedido de senha funciona com a fonte no maior tamanho', (WidgetTester tester) async {
    await openElevation(tester, build(token: 'gs_x'), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pedido de senha segue as diretrizes de acessibilidade', (WidgetTester tester) async {
    await openElevation(tester, build(token: 'gs_x'));
    await expectAccessible(tester);
  });
}

/// Monta uma tela com um BLoC novo, no tema e no tamanho de fonte pedidos.
typedef _Pump = Future<void> Function(
  WidgetTester tester,
  TestDependencies deps, {
  Brightness brightness,
  double textScale,
  Size size,
});
