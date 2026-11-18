import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/core/navigation/launch_action.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';
import 'package:parentalynx/features/guardian/guardian_module.dart';
import 'package:parentalynx/features/guardian/guardian_routes.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notifications/notifications_bloc.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/native_doubles.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  group('casca do painel', () {
    late TestDependencies deps;
    late DevicesBloc devices;

    TestDependencies createDeps({bool notificationsAllowed = true, bool withDevice = true}) {
      final TestDependencies created = TestDependencies(
        sessionToken: 'gs_x',
        native: NativeDoubles(notificationsAllowed: notificationsAllowed),
      );
      registerNotificationsModule(created.di);
      registerGuardianModule(created.di);
      created.backend
        ..onJson('GET', '/v1/guardian/alerts', <String, Object?>{
          'alerts': <Object?>[],
          'latestId': 7,
          'unread': 3,
        })
        ..onJson('GET', '/v1/guardian/devices', <String, Object?>{
          'devices': <Object?>[if (withDevice) deviceJson()],
        });
      return created;
    }

    setUp(() => deps = createDeps());

    tearDown(() => deps.dispose());

    /// Casca com cinco abas simples; a quarta e a aba Alertas.
    Future<GoRouter> pumpShell(WidgetTester tester, {Brightness brightness = Brightness.light}) {
      return pumpGuardianRoutes(
        tester,
        routes: <RouteBase>[
          guardianShellRoute(
            deps.di,
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
        location: '/a',
        deps: deps,
        brightness: brightness,
        // No app estes BLoCs vivem no escopo da sessao, acima da casca.
        wrap: (Widget app) => MultiBlocProvider(
          providers: <BlocProvider<Object?>>[
            BlocProvider<DevicesBloc>(
              lazy: false,
              create: (BuildContext context) {
                return devices = deps.di<DevicesBloc>()..add(const DevicesStarted());
              },
            ),
            BlocProvider<NotificationsBloc>(
              create: (BuildContext context) {
                return deps.di<NotificationsBloc>()..add(const NotificationsStarted());
              },
            ),
            BlocProvider<NotificationPermissionBloc>(
              create: (BuildContext context) {
                return deps.di<NotificationPermissionBloc>()
                  ..add(const NotificationPermissionStarted());
              },
            ),
          ],
          child: app,
        ),
      );
    }

    void emitAlert(int id) {
      deps.realtime.emit(
        AlertRaised(
          RealtimeAlert(
            id: id,
            type: 'limit_reached',
            deviceId: 'd1',
            childName: 'João',
            createdAt: deps.clock.now().millisecondsSinceEpoch,
            notify: true,
            title: 'Limite diário atingido',
            body: 'João usou as 2h30 de hoje.',
          ),
        ),
      );
    }

    /// Deixa o aviso do alerta sair da tela antes do fim do teste.
    Future<void> letToastExpire(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
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
      await pumpShell(tester);

      deps.launchActions.open(LaunchAction.alerts);
      await settle(tester);

      expect(find.text('pagina alertas'), findsOneWidget);
      expect(deps.launchActions.pending, isNull);
    });

    testWidgets('acao de abertura pendente antes da casca tambem leva aos alertas', (
      WidgetTester tester,
    ) async {
      deps.launchActions.open(LaunchAction.alerts);
      await pumpShell(tester);

      expect(find.text('pagina alertas'), findsOneWidget);
      expect(deps.launchActions.pending, isNull);
    });

    testWidgets('acoes do modo crianca ficam pendentes', (WidgetTester tester) async {
      await pumpShell(tester);

      deps.launchActions.open(LaunchAction.childHome);
      await settle(tester);

      expect(find.text('pagina a'), findsOneWidget);
      expect(deps.launchActions.pending, LaunchAction.childHome);
    });

    testWidgets('alerta em tempo real mostra o aviso e aumenta o selo', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester);

      emitAlert(9);
      await settle(tester);

      expect(find.textContaining('Limite diário atingido'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      verify(() => deps.native.guardian.setLastSeenAlertId(9)).called(1);
      await letToastExpire(tester);
      expect(find.textContaining('Limite diário atingido'), findsNothing);
    });

    testWidgets('Ver no aviso abre a aba Alertas', (WidgetTester tester) async {
      await pumpShell(tester);

      emitAlert(9);
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Ver'));
      await settle(tester);

      expect(find.text('pagina alertas'), findsOneWidget);
      expect(find.textContaining('Limite diário atingido'), findsNothing);
    });

    testWidgets('o aviso pode ser dispensado e segue as diretrizes de acessibilidade', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester);

      emitAlert(9);
      await settle(tester);
      // As abas aqui sao paginas de teste; o contraste do aviso vem dos papeis de cor do
      // Design System para fundos invertidos (os mesmos das confirmacoes curtas).
      await expectAccessible(tester, checkContrast: false);

      await tester.tap(find.byTooltip('Dispensar aviso'));
      await settle(tester);
      expect(find.textContaining('Limite diário atingido'), findsNothing);
    });

    testWidgets('o aviso funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpShell(tester);

      emitAlert(9);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Limite diário atingido'), findsOneWidget);
      await letToastExpire(tester);
    });

    testWidgets('na primeira vez sem permissao explica e pede as notificacoes', (
      WidgetTester tester,
    ) async {
      await deps.dispose();
      deps = createDeps(notificationsAllowed: false);
      await pumpShell(tester);

      expect(find.text('Ativar notificações?'), findsOneWidget);
      expect(deps.preferences.values[LocalPrefKeys.notificationsPrompted], isTrue);
      await tester.tap(find.text('Ativar'));
      await settle(tester);

      verify(deps.native.device.requestNotificationPermission).called(1);
      expect(find.text('Ativar notificações?'), findsNothing);
    });

    testWidgets('sem aparelho vinculado espera o primeiro aparelho para pedir as notificacoes', (
      WidgetTester tester,
    ) async {
      await deps.dispose();
      deps = createDeps(notificationsAllowed: false, withDevice: false);
      await pumpShell(tester);

      // Os avisos sao sobre o aparelho da crianca: sem aparelho, ainda nao pergunta.
      expect(find.text('Ativar notificações?'), findsNothing);
      expect(deps.preferences.values[LocalPrefKeys.notificationsPrompted], isNull);

      deps.backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
        'devices': <Object?>[deviceJson()],
      });
      devices.add(const DevicesRefreshRequested());
      await settle(tester);

      expect(find.text('Ativar notificações?'), findsOneWidget);
      expect(deps.preferences.values[LocalPrefKeys.notificationsPrompted], isTrue);
    });

    testWidgets('com a permissao ja concedida nao pergunta nada', (WidgetTester tester) async {
      await pumpShell(tester);

      expect(find.text('Ativar notificações?'), findsNothing);
      expect(deps.preferences.values[LocalPrefKeys.notificationsPrompted], isTrue);
      verifyNever(deps.native.device.requestNotificationPermission);
    });

    group('capturas', () {
      for (final Brightness brightness in Brightness.values) {
        final String theme = brightness == Brightness.light ? '' : '_escuro';

        testWidgets('aviso de alerta sobre as abas$theme', tags: 'screenshot', (
          WidgetTester tester,
        ) async {
          await pumpShell(tester, brightness: brightness);

          emitAlert(9);
          await settle(tester);
          await expectScreenshot(tester, 'guardian_shell_alerta$theme');
          await letToastExpire(tester);
        });
      }
    });
  });
}
