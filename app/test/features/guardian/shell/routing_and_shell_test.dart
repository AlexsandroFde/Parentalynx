import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/app/app.dart';
import 'package:parentalynx/app/router.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/platform/native_providers.dart';
import 'package:parentalynx/features/guardian/auth/presentation/recovery_key_page.dart';
import 'package:parentalynx/features/guardian/auth/presentation/register_page.dart';
import 'package:parentalynx/features/guardian/auth/presentation/session_controller.dart';
import 'package:parentalynx/features/guardian/auth/presentation/sign_in_page.dart';
import 'package:parentalynx/features/guardian/auth/presentation/unlock_page.dart';
import 'package:parentalynx/features/guardian/devices/presentation/devices_page.dart';
import 'package:parentalynx/features/guardian/guardian_paths.dart';
import 'package:parentalynx/features/guardian/pairing/presentation/pairing_page.dart';
import 'package:parentalynx/features/guardian/realtime/guardian_realtime.dart';
import 'package:parentalynx/features/guardian/shell/presentation/guardian_shell.dart';

import '../../../support/test_app.dart';
import '../support/guardian_test_support.dart';

void main() {
  late FakeBackend backend;
  late NativeDoubles native;

  setUp(() {
    backend = FakeBackend();
    native = NativeDoubles();
    backend.onJson('GET', '/v1/guardian/me', <String, Object?>{
      'guardian': guardianJson(),
      'session': sessionJson(),
    });
    backend.onJson('POST', '/v1/guardian/session/elevate', <String, Object?>{'elevatedUntil': 123});
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
      'devices': <Object?>[deviceJson()],
    });
    backend.onJson('GET', '/v1/guardian/pairing-codes/active', <String, Object?>{
      'code': null,
      'pending': <Object?>[],
    });
    backend.onJson('GET', '/v1/guardian/alerts', <String, Object?>{
      'alerts': <Object?>[],
      'latestId': 7,
      'unread': 3,
    });
  });

  void usePhone(WidgetTester tester) {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = phoneSize * 2.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<ProviderContainer> pumpApp(WidgetTester tester, {String? token}) async {
    usePhone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: guardianOverrides(backend: backend, native: native, sessionToken: token),
        child: const ParentaLynxApp(),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(ParentaLynxApp)));
  }

  group('roteamento do modo responsavel', () {
    testWidgets('sem sessao abre a porta de entrada', (WidgetTester tester) async {
      await pumpApp(tester);
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('sem sessao, uma rota protegida leva para a porta de entrada', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpApp(tester);
      container.read(routerProvider).go(GuardianPaths.devices);
      await settle(tester);
      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(DevicesPage), findsNothing);
    });

    testWidgets('com token gravado a abertura a frio pede a senha', (WidgetTester tester) async {
      await pumpApp(tester, token: 'gs_x');
      expect(find.byType(UnlockPage), findsOneWidget);
      expect(find.text('Painel bloqueado'), findsOneWidget);
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

    testWidgets('bloqueado, guarda a rota pedida e volta para ela ao desbloquear', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpApp(tester, token: 'gs_x');
      container.read(routerProvider).go(GuardianPaths.devices);
      await settle(tester);
      expect(find.byType(UnlockPage), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Girassol-azul-42');
      await tester.tap(find.text('Desbloquear'));
      await settle(tester);

      expect(find.byType(DevicesPage), findsOneWidget);
      expect(find.text('João'), findsOneWidget);
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
      final ProviderContainer container = await pumpApp(tester);

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

      // Sem marcar a caixa, o botao de continuar fica inativo.
      final FilledButton proceed = tester.widget(find.widgetWithText(FilledButton, 'Continuar'));
      expect(proceed.onPressed, isNull);

      // O destino depois da chave e desviado para uma tela desta frente.
      container.read(guardianReturnLocationProvider).remember(GuardianPaths.pairing);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await settle(tester);

      expect(find.byType(PairingPage), findsOneWidget);
    });
  });

  group('casca do painel', () {
    late StreamController<GuardianRealtimeEvent> realtime;

    Future<ProviderContainer> pumpShell(WidgetTester tester) async {
      usePhone(tester);
      realtime = StreamController<GuardianRealtimeEvent>.broadcast();
      addTearDown(realtime.close);
      final GoRouter router = GoRouter(
        initialLocation: '/a',
        routes: <RouteBase>[
          StatefulShellRoute.indexedStack(
            builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) {
              return GuardianShell(navigationShell: shell);
            },
            branches: <StatefulShellBranch>[
              for (final String name in <String>['a', 'b', 'c', 'alertas', 'e'])
                StatefulShellBranch(
                  routes: <RouteBase>[
                    GoRoute(
                      path: '/$name',
                      builder: (BuildContext context, GoRouterState state) {
                        return Scaffold(body: Center(child: Text('pagina $name')));
                      },
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: guardianOverrides(
            backend: backend,
            native: native,
            sessionToken: 'gs_x',
            realtime: realtime.stream,
          ),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const <Locale>[appLocale],
          ),
        ),
      );
      await settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(GuardianShell)));
    }

    testWidgets('mostra as cinco abas e o selo de alertas nao lidos', (WidgetTester tester) async {
      await pumpShell(tester);

      for (final String label in <String>['Início', 'Regras', 'Relatórios', 'Alertas', 'Mais']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('3'), findsOneWidget);
      expect(find.text('pagina a'), findsOneWidget);

      await tester.tap(find.text('Mais'));
      await settle(tester);
      expect(find.text('pagina e'), findsOneWidget);
    });

    testWidgets('a acao de abertura alerts leva para a aba Alertas', (WidgetTester tester) async {
      final ProviderContainer container = await pumpShell(tester);

      container.read(launchActionProvider.notifier).receive('alerts');
      await settle(tester);

      expect(find.text('pagina alertas'), findsOneWidget);
      expect(container.read(launchActionProvider), isNull);
    });

    testWidgets('alerta em tempo real mostra o aviso e aumenta o selo', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester);

      realtime.add(
        GuardianRealtimeEvent.fromJson(
          JsonMap(<String, Object?>{'type': 'alert', 'alert': alertJson(id: 9)}),
        ),
      );
      await settle(tester);

      expect(find.textContaining('Limite diário atingido'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      verify(() => native.guardian.setLastSeenAlertId(9)).called(1);
      // Deixa o aviso sair da tela antes do fim do teste.
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
    });
  });
}
