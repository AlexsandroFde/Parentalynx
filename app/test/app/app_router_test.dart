import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/authentication/presentation/pages/recovery_key_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/register_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/sign_in_page.dart';
import 'package:parentalynx/features/authentication/presentation/pages/unlock_page.dart';
import 'package:parentalynx/features/child_device/presentation/pages/devices_page.dart';
import 'package:parentalynx/features/child_mode/presentation/pages/child_home_page.dart';
import 'package:parentalynx/features/device_linking/presentation/pages/link_page.dart';
import 'package:parentalynx/features/guardian/presentation/pages/dashboard_page.dart';
import 'package:parentalynx/features/guardian/presentation/widgets/guardian_shell.dart';
import 'package:parentalynx/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';

import '../features/child_mode/support/child_app.dart' show unmountChildApp;
import '../features/child_mode/support/child_fakes.dart'
    show ChildBridge, fakeStatus, registerChildFallbacks;
import '../support/app_test_dependencies.dart';
import '../support/fake_backend.dart';
import '../support/guardian_api_fixtures.dart' show installStandardRoutes;
import '../support/guardian_fixtures.dart' show authJson, guardianJson, sessionJson;
import '../support/native_doubles.dart';
import '../support/test_dependencies.dart';

void main() {
  late FakeBackend backend;
  late TestDependencies deps;

  setUp(() {
    backend = FakeBackend();
    // Um aparelho ativo (João) com politica, apps, alertas e relatorio.
    installStandardRoutes(backend);
    backend
      ..onJson('GET', '/v1/guardian/me', <String, Object?>{
        'guardian': guardianJson(),
        'session': sessionJson(),
      })
      ..onJson('POST', '/v1/guardian/session/elevate', <String, Object?>{'elevatedUntil': 123})
      ..onJson('GET', '/v1/guardian/pairing-codes/active', <String, Object?>{
        'code': null,
        'pending': <Object?>[],
      });
  });

  tearDown(() => deps.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    UserRole role = UserRole.guardian,
    String? token,
    NativeDoubles? native,
  }) {
    deps = buildAppTestDependencies(
      backend: backend,
      native: native,
      role: role,
      sessionToken: token,
    );
    return pumpParentaLynxApp(tester, deps);
  }

  /// O roteador do app, achado a partir de qualquer tela montada por ele.
  GoRouter routerOf(WidgetTester tester, Type page) =>
      GoRouter.of(tester.element(find.byType(page)));

  group('perfil', () {
    testWidgets('sem perfil escolhido abre as boas-vindas', (WidgetTester tester) async {
      await pumpApp(tester, role: UserRole.unset);
      expect(find.byType(WelcomePage), findsOneWidget);
    });

    testWidgets('sem perfil, qualquer rota volta para as boas-vindas', (WidgetTester tester) async {
      await pumpApp(tester, role: UserRole.unset);
      routerOf(tester, WelcomePage).go(GuardianPaths.devices);
      await settle(tester);
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(DevicesPage), findsNothing);
    });
  });

  group('roteamento do modo responsavel', () {
    testWidgets('sem sessao abre a porta de entrada', (WidgetTester tester) async {
      await pumpApp(tester);
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('sem sessao, uma rota protegida leva para a porta de entrada', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      routerOf(tester, SignInPage).go(GuardianPaths.devices);
      await settle(tester);
      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(DevicesPage), findsNothing);
    });

    testWidgets('com perfil de responsavel, a area da crianca leva para o painel', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      routerOf(tester, SignInPage).go(ChildPaths.home);
      await settle(tester);
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('com token gravado a abertura a frio pede a senha', (WidgetTester tester) async {
      await pumpApp(tester, token: 'gs_x');
      expect(find.byType(UnlockPage), findsOneWidget);
      expect(find.text('Painel bloqueado'), findsOneWidget);
      // Bloqueado, o painel nao monta: nenhuma leitura do servidor foi feita.
      expect(backend.calls('GET', '/v1/guardian/devices'), isEmpty);
    });

    testWidgets('senha errada mantem bloqueado e mostra o motivo', (WidgetTester tester) async {
      backend.onError(
        'POST',
        '/v1/guardian/session/elevate',
        status: 401,
        code: 'invalid_credentials',
      );
      await pumpApp(tester, token: 'gs_x');

      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(find.text('Desbloquear'));
      await settle(tester);

      expect(find.text('Senha incorreta.'), findsOneWidget);
      expect(find.byType(UnlockPage), findsOneWidget);
    });

    testWidgets('desbloquear sem destino guardado abre o inicio do painel', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, token: 'gs_x');

      await tester.enterText(find.byType(TextField), 'Girassol-azul-42');
      await tester.tap(find.text('Desbloquear'));
      await settle(tester);

      expect(find.byType(GuardianShell), findsOneWidget);
      expect(find.byType(DashboardPage), findsOneWidget);
    });

    testWidgets('bloqueado, guarda a rota pedida e volta para ela ao desbloquear', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, token: 'gs_x');
      routerOf(tester, UnlockPage).go(GuardianPaths.devices);
      await settle(tester);
      expect(find.byType(UnlockPage), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Girassol-azul-42');
      await tester.tap(find.text('Desbloquear'));
      await settle(tester);

      expect(find.byType(DevicesPage), findsOneWidget);
      expect(find.text('João'), findsWidgets);
    });

    testWidgets('registro leva a chave de recuperacao e so depois ao painel', (
      WidgetTester tester,
    ) async {
      backend.onJson(
        'POST',
        '/v1/auth/register',
        authJson(recoveryKey: 'RK-AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'),
        status: 201,
      );
      await pumpApp(tester);

      await tester.tap(find.text('Criar conta'));
      await settle(tester);
      expect(find.byType(RegisterPage), findsOneWidget);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Maria Souza');
      await tester.enterText(fields.at(1), 'maria@exemplo.com');
      await tester.enterText(fields.at(2), 'Girassol-azul-42');
      await tester.enterText(fields.at(3), 'Girassol-azul-42');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar conta').last);
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta').last);
      await settle(tester);

      expect(find.byType(RecoveryKeyPage), findsOneWidget);
      expect(find.text('RK-AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'), findsOneWidget);

      // Com a chave pendente, o painel nao abre nem por navegacao direta.
      routerOf(tester, RecoveryKeyPage).go(GuardianPaths.home);
      await settle(tester);
      expect(find.byType(RecoveryKeyPage), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);

      // Sem marcar a caixa, o botao de continuar fica inativo.
      final FilledButton proceed = tester.widget(find.widgetWithText(FilledButton, 'Continuar'));
      expect(proceed.onPressed, isNull);

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await settle(tester);
      // Deixa a transicao de saida da tela da chave terminar.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.byType(RecoveryKeyPage), findsNothing);
    });
  });

  group('roteamento do modo crianca', () {
    late ChildBridge bridge;

    setUpAll(registerChildFallbacks);

    setUp(() {
      bridge = ChildBridge(NativeDoubles());
    });

    /// Abre o app no perfil crianca e espera a consulta ao agente decidir a area.
    Future<void> pumpChild(WidgetTester tester) async {
      await pumpApp(tester, role: UserRole.child, native: bridge.native);
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('aparelho sem vinculo abre a tela do codigo', (WidgetTester tester) async {
      bridge.status = fakeStatus(active: false);
      await pumpChild(tester);

      expect(find.byType(LinkPage), findsOneWidget);
      expect(find.text('Vincular este aparelho'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('aparelho vinculado abre a tela inicial da crianca', (WidgetTester tester) async {
      await pumpChild(tester);

      expect(find.byType(ChildHomePage), findsOneWidget);
      expect(find.text('Olá, João!'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('no aparelho da crianca o painel do responsavel nao abre', (
      WidgetTester tester,
    ) async {
      await pumpChild(tester);
      routerOf(tester, ChildHomePage).go(GuardianPaths.home);
      await settle(tester);

      expect(find.byType(ChildHomePage), findsOneWidget);
      expect(find.byType(GuardianShell), findsNothing);
      expect(find.byType(SignInPage), findsNothing);
      await unmountChildApp(tester, deps.di);
    });
  });
}
