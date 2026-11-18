import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/domain/repositories/i_session_repository.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/auth/auth_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/guardian_entry/guardian_entry_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/login/login_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/register/register_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/unlock/unlock_bloc.dart';
import 'package:parentalynx/features/authentication/presentation/pages/login_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/recovery_key_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/register_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/sign_in_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/unlock_page.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

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

  testWidgets('porta de entrada', tags: 'screenshot', (WidgetTester tester) async {
    final TestDependencies deps = build();
    await pumpWidgetInApp(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: deps.di<AuthBloc>()),
          BlocProvider<GuardianEntryBloc>(
            create: (BuildContext context) =>
                deps.di<GuardianEntryBloc>()..add(const GuardianEntryStarted()),
          ),
        ],
        child: const SignInPage(),
      ),
      di: deps.di,
    );
    await settle(tester);

    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
    expect(find.text('Voltar para a escolha de modo'), findsOneWidget);
    expect(find.text('Servidor: https://servidor.teste'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_sign_in');
  });

  Future<void> pumpRegister(WidgetTester tester, TestDependencies deps) {
    return pumpWidgetInApp(
      tester,
      BlocProvider<RegisterBloc>(
        create: (BuildContext context) => deps.di<RegisterBloc>()..add(const RegisterStarted()),
        child: const RegisterPage(),
      ),
      di: deps.di,
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
    await tester.ensureVisible(find.text('Criar conta').first);
    await settle(tester);
    expect(find.textContaining('Força:'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_register');
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
    final TestDependencies deps = build();
    await pumpWidgetInApp(
      tester,
      BlocProvider<LoginBloc>(
        create: (BuildContext context) => deps.di<LoginBloc>(),
        child: const LoginPage(),
      ),
      di: deps.di,
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'maria@exemplo.com');
    await tester.enterText(find.byType(TextField).at(1), 'qualquer');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await settle(tester);

    expect(find.text('Muitas tentativas. Tente de novo em 2 minutos.'), findsOneWidget);
  });

  testWidgets('chave de recuperacao: copiar e confirmar', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
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
    await pumpWidgetInApp(
      tester,
      BlocProvider<AuthBloc>.value(value: deps.di<AuthBloc>(), child: const RecoveryKeyPage()),
      di: deps.di,
    );
    await settle(tester);

    await tester.tap(find.text('Copiar'));
    await settle(tester);
    expect(deps.share.copied.single, 'RK-7H2KD-9QWXA-4MNP8-TZ5VB-C3RGE');
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await expectScreenshot(tester, 'guardian_recovery_key');

    await tester.tap(find.byType(CheckboxListTile));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await settle(tester);
    final AuthState state = deps.di<AuthBloc>().state;
    expect(state, isA<AuthReady>());
    expect((state as AuthReady).pendingRecoveryKey, isNull);
  });

  testWidgets('tela de bloqueio mostra a conta gravada', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = build(
      token: 'gs_x',
      store: InMemorySecureStore(<String, String>{StorageKeys.guardianEmail: 'maria@exemplo.com'}),
    );
    await pumpWidgetInApp(
      tester,
      BlocProvider<UnlockBloc>(
        create: (BuildContext context) => deps.di<UnlockBloc>()..add(const UnlockStarted()),
        child: const UnlockPage(),
      ),
      di: deps.di,
    );
    await settle(tester);

    expect(find.textContaining('maria@exemplo.com'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_unlock');
  });
}
