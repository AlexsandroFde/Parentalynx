import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';
import 'package:parentalynx/features/notifications/notifications_routes.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notifications/notifications_bloc.dart';
import 'package:parentalynx/features/notifications/presentation/pages/alerts_center_page.dart';

import '../../../support/fakes.dart';
import '../../../support/guardian_api_fixtures.dart' show pumpGuardianRoutes, settle;
import '../../../support/guardian_fixtures.dart';
import '../../../support/native_doubles.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String readPath = '/v1/guardian/alerts/read';

  late TestDependencies deps;

  TestDependencies createDeps({bool notificationsAllowed = true}) {
    final Map<String, Object?> devices = <String, Object?>{
      'devices': <Object?>[
        deviceJson(pendingTimeRequests: 1, issues: <String>['accessibility_disabled']),
      ],
    };
    final Map<String, Object?> alerts = <String, Object?>{
      'alerts': <Object?>[
        alertJson(
          id: 4,
          type: 'time_request',
          title: 'Pedido de tempo adicional',
          body: 'João pediu mais 30 minutos.',
          createdAt: minutesAgo(3),
        ),
        alertJson(id: 3, createdAt: minutesAgo(25)),
        alertJson(
          id: 2,
          type: 'permission_changed',
          title: 'Permissão desativada',
          body: 'O serviço de acessibilidade foi desativado no aparelho de João.',
          read: true,
          createdAt: minutesAgo(50),
        ),
        alertJson(
          id: 1,
          type: 'blocked_app_attempt',
          title: 'Tentativa de abrir app bloqueado',
          body: 'João tentou abrir o TikTok.',
          read: true,
          createdAt: minutesAgo(58),
        ),
      ],
      'latestId': 4,
      'unread': 2,
    };
    // Os exemplos usam o relogio real ("ha 3 min"): o relogio do teste parte de depois deles.
    final TestDependencies created = TestDependencies(
      sessionToken: 'gs_x',
      clock: FakeClock(DateTime.now()),
      native: NativeDoubles(notificationsAllowed: notificationsAllowed),
    );
    registerNotificationsModule(created.di);
    created.backend
      ..onJson('GET', '/v1/guardian/devices', devices)
      ..onJson('GET', '/v1/guardian/alerts', alerts)
      ..onJson('POST', readPath, <String, Object?>{'unread': 1});
    return created;
  }

  setUp(() => deps = createDeps());

  tearDown(() => deps.dispose());

  /// BLoCs que no app vivem no escopo da sessao, acima das abas.
  Widget sessionScope(Widget child) {
    return MultiBlocProvider(
      providers: <BlocProvider<Object?>>[
        BlocProvider<DevicesBloc>(
          create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
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
      child: child,
    );
  }

  Future<GoRouter> pumpAlerts(WidgetTester tester) {
    return pumpGuardianRoutes(
      tester,
      routes: <RouteBase>[
        alertsRoute(
          deps.di,
          children: <RouteBase>[
            GoRoute(
              path: 'time-requests',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(body: Center(child: Text('pedidos de tempo')));
              },
            ),
          ],
        ),
      ],
      location: GuardianPaths.alerts,
      deps: deps,
      destinations: const <String>[],
      wrap: sessionScope,
    );
  }

  testWidgets('central de alertas', tags: 'screenshot', (WidgetTester tester) async {
    await pumpWidgetInApp(tester, sessionScope(const AlertsCenterPage()), di: deps.di);
    await settle(tester);

    expect(find.text('1 pedido de tempo aguardando resposta'), findsOneWidget);
    expect(find.text('Limite diário atingido'), findsOneWidget);
    expect(find.textContaining('até cerca de 15 minutos'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_alerts');
  });

  testWidgets('abrir um alerta marca como lido e mostra o detalhe', (WidgetTester tester) async {
    await pumpAlerts(tester);

    await tester.tap(find.text('Limite diário atingido'));
    await settle(tester);

    expect(deps.backend.lastBody('POST', readPath), <String, Object?>{
      'ids': <Object?>[3],
    });
    expect(find.text('Ver aparelho'), findsOneWidget);
    expect(find.textContaining('Limite diário atingido · João · '), findsOneWidget);
  });

  testWidgets('pedido de tempo leva para a tela de resposta', (WidgetTester tester) async {
    await pumpAlerts(tester);

    await tester.tap(find.text('Pedido de tempo adicional'));
    await settle(tester);
    await tester.tap(find.text('Responder pedido'));
    await settle(tester);

    expect(find.text('pedidos de tempo'), findsOneWidget);
  });

  testWidgets('marcar todos como lidos usa a rota do protocolo', (WidgetTester tester) async {
    await pumpAlerts(tester);
    deps.backend.onJson('POST', readPath, <String, Object?>{'unread': 0});

    await tester.tap(find.byTooltip('Marcar todos como lidos'));
    await settle(tester);

    expect(deps.backend.lastBody('POST', readPath), <String, Object?>{'all': true});
    final IconButton button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.done_all),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('notificacoes desativadas aparecem com o atalho para ativar', (
    WidgetTester tester,
  ) async {
    await deps.dispose();
    deps = createDeps(notificationsAllowed: false);
    await pumpAlerts(tester);

    expect(find.text('Notificações desativadas'), findsOneWidget);
    await tester.tap(find.text('Ativar notificações'));
    await settle(tester);
    expect(find.text('Ativar notificações?'), findsOneWidget);

    await tester.tap(find.text('Ativar'));
    await settle(tester);
    verify(deps.native.device.requestNotificationPermission).called(1);
  });

  testWidgets('o atalho das preferencias abre a tela de preferencias', (WidgetTester tester) async {
    await pumpAlerts(tester);

    await tester.tap(find.byTooltip('Preferências de notificação'));
    await settle(tester);

    expect(find.text('Preferências de notificação'), findsOneWidget);
  });
}
