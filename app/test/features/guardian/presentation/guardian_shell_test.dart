import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/core/navigation/launch_action.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';
import 'package:parentalynx/features/guardian/guardian_module.dart';
import 'package:parentalynx/features/guardian/guardian_routes.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notifications/notifications_bloc.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/native_doubles.dart';
import '../../../support/test_dependencies.dart';

void main() {
  group('casca do painel', () {
    late TestDependencies deps;

    TestDependencies createDeps({bool notificationsAllowed = true}) {
      final TestDependencies created = TestDependencies(
        sessionToken: 'gs_x',
        native: NativeDoubles(notificationsAllowed: notificationsAllowed),
      );
      registerNotificationsModule(created.di);
      registerGuardianModule(created.di);
      created.backend.onJson('GET', '/v1/guardian/alerts', <String, Object?>{
        'alerts': <Object?>[],
        'latestId': 7,
        'unread': 3,
      });
      return created;
    }

    setUp(() => deps = createDeps());

    tearDown(() => deps.dispose());

    /// Casca com cinco abas simples; a quarta e a aba Alertas.
    Future<GoRouter> pumpShell(WidgetTester tester) {
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
        // No app estes BLoCs vivem no escopo da sessao, acima da casca.
        wrap: (Widget app) => MultiBlocProvider(
          providers: <BlocProvider<Object?>>[
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
      // Deixa o aviso sair da tela antes do fim do teste.
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
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

    testWidgets('com a permissao ja concedida nao pergunta nada', (WidgetTester tester) async {
      await pumpShell(tester);

      expect(find.text('Ativar notificações?'), findsNothing);
      expect(deps.preferences.values[LocalPrefKeys.notificationsPrompted], isTrue);
      verifyNever(deps.native.device.requestNotificationPermission);
    });
  });
}
