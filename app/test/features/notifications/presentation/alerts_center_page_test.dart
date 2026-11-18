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
import 'package:parentalynx/shared/design_system/design_system.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/guardian_api_fixtures.dart' show pumpGuardianRoutes, settle;
import '../../../support/guardian_fixtures.dart';
import '../../../support/native_doubles.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

/// Momento fixo dos exemplos: os grupos por dia e os horarios ficam estaveis nas capturas.
final DateTime _now = DateTime(2026, 11, 17, 15, 30);

int _ago(Duration ago) => _now.subtract(ago).millisecondsSinceEpoch;

Map<String, Object?> _alert({
  required int id,
  required String type,
  required String title,
  required String body,
  required int createdAt,
  bool read = false,
  bool notify = true,
}) {
  return <String, Object?>{
    'id': id,
    'type': type,
    'deviceId': 'd1',
    'childName': 'João',
    'createdAt': createdAt,
    'readAt': read ? 10 : null,
    'notify': notify,
    'title': title,
    'body': body,
    'data': <String, Object?>{},
  };
}

void main() {
  const String alertsPath = '/v1/guardian/alerts';
  const String readPath = '/v1/guardian/alerts/read';

  late TestDependencies deps;

  final Map<String, Object?> alerts = <String, Object?>{
    'alerts': <Object?>[
      _alert(
        id: 5,
        type: 'time_request',
        title: 'Pedido de tempo adicional',
        body: 'João pediu mais 30 minutos.',
        createdAt: _ago(const Duration(minutes: 3)),
      ),
      _alert(
        id: 4,
        type: 'limit_reached',
        title: 'Limite diário atingido',
        body: 'João usou as 2h30 de hoje.',
        createdAt: _ago(const Duration(minutes: 25)),
      ),
      _alert(
        id: 3,
        type: 'permission_changed',
        title: 'Permissão desativada',
        body: 'O serviço de acessibilidade foi desativado no aparelho de João.',
        createdAt: _ago(const Duration(minutes: 50)),
        read: true,
      ),
      _alert(
        id: 2,
        type: 'blocked_app_attempt',
        title: 'Tentativa de abrir app bloqueado',
        body: 'João tentou abrir o TikTok.',
        createdAt: _ago(const Duration(hours: 19, minutes: 20)),
        read: true,
      ),
      _alert(
        id: 1,
        type: 'new_app_installed',
        title: 'Novo app instalado',
        body: 'Roblox foi instalado no aparelho de João.',
        createdAt: _ago(const Duration(hours: 21)),
        read: true,
        notify: false,
      ),
    ],
    'latestId': 5,
    'unread': 2,
  };

  TestDependencies createDeps({bool notificationsAllowed = true}) {
    final TestDependencies created = TestDependencies(
      sessionToken: 'gs_x',
      clock: FakeClock(_now),
      native: NativeDoubles(notificationsAllowed: notificationsAllowed),
    );
    registerNotificationsModule(created.di);
    created.backend
      ..onJson('GET', '/v1/guardian/devices', <String, Object?>{
        'devices': <Object?>[
          deviceJson(pendingTimeRequests: 1, issues: <String>['accessibility_disabled']),
        ],
      })
      ..onJson('GET', alertsPath, alerts)
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

  Future<void> pumpCenter(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    await pumpWidgetInApp(
      tester,
      sessionScope(const AlertsCenterPage()),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: const Size(392, 1020),
    );
    await settle(tester);
  }

  testWidgets('central de alertas agrupada por dia, com os novos marcados', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpCenter(tester);

    expect(find.text('1 pedido de tempo aguardando resposta'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Ontem'), findsOneWidget);
    // Nao lido aparece em texto (etiqueta), nao so na cor.
    expect(find.text('Novo'), findsNWidgets(2));
    expect(find.text('João · há 25 min'), findsOneWidget);
    expect(find.textContaining('até cerca de 15 minutos'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_alerts');
  });

  testWidgets('central de alertas no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
    await pumpCenter(tester, brightness: Brightness.dark);
    await expectScreenshot(tester, 'guardian_alerts_escuro');
  });

  testWidgets('central de alertas segue as diretrizes de acessibilidade', (
    WidgetTester tester,
  ) async {
    await pumpCenter(tester);
    await expectAccessible(tester);
  });

  testWidgets('central de alertas funciona com a fonte no maior tamanho', (
    WidgetTester tester,
  ) async {
    await pumpCenter(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Limite diário atingido'), findsOneWidget);
  });

  testWidgets('abrir um alerta marca como lido e mostra o detalhe', (WidgetTester tester) async {
    await pumpAlerts(tester);

    await tester.tap(find.text('Limite diário atingido'));
    await settle(tester);

    expect(deps.backend.lastBody('POST', readPath), <String, Object?>{
      'ids': <Object?>[4],
    });
    expect(find.text('João · hoje às 15:05'), findsOneWidget);
    expect(find.text('Ver aparelho'), findsOneWidget);
  });

  testWidgets('alerta que nao gerou notificacao explica o motivo', (WidgetTester tester) async {
    await pumpAlerts(tester);

    await tester.ensureVisible(find.text('Novo app instalado'));
    await settle(tester);
    await tester.tap(find.text('Novo app instalado'));
    await settle(tester);

    expect(find.textContaining('desligado nas preferências'), findsOneWidget);
    expect(find.text('Ver regras de apps'), findsOneWidget);
  });

  testWidgets('pedido de tempo pendente leva para a tela de resposta', (WidgetTester tester) async {
    await pumpAlerts(tester);

    await tester.tap(find.text('Pedido de tempo adicional'));
    await settle(tester);
    expect(find.text('Aguardando a sua resposta'), findsOneWidget);
    await tester.tap(find.text('Responder pedido'));
    await settle(tester);

    expect(find.text('pedidos de tempo'), findsOneWidget);
  });

  testWidgets('marcar todos como lidos pede confirmacao e avisa depois que o servidor aceita', (
    WidgetTester tester,
  ) async {
    await pumpAlerts(tester);
    deps.backend.onJson('POST', readPath, <String, Object?>{'unread': 0});

    await tester.tap(find.byTooltip('Marcar todos como lidos'));
    await settle(tester);
    expect(find.text('Marcar 2 alertas como lidos?'), findsOneWidget);
    expect(deps.backend.calls('POST', readPath), isEmpty);

    await tester.tap(find.text('Marcar como lidos'));
    await settle(tester);

    expect(deps.backend.lastBody('POST', readPath), <String, Object?>{'all': true});
    expect(find.text('Todos os alertas foram marcados como lidos.'), findsOneWidget);
    expect(find.text('Novo'), findsNothing);
    final IconButton button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, AppIcons.checkAll),
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

  testWidgets('sem alertas explica o que aparece e leva as preferencias', (
    WidgetTester tester,
  ) async {
    deps.backend.onJson('GET', alertsPath, <String, Object?>{
      'alerts': <Object?>[],
      'latestId': 0,
      'unread': 0,
    });
    await pumpAlerts(tester);

    expect(find.text('Nenhum alerta por enquanto'), findsOneWidget);
    await tester.tap(find.text('Escolher avisos'));
    await settle(tester);
    expect(find.text('Quais avisos tocam no celular'), findsOneWidget);
  });

  testWidgets('falha ao carregar diz o que houve e oferece tentar de novo', (
    WidgetTester tester,
  ) async {
    deps.backend.on('GET', alertsPath, (_) => errorResponse(500, 'internal'));
    await pumpAlerts(tester);

    expect(find.text('Não foi possível carregar os alertas'), findsOneWidget);
    deps.backend.onJson('GET', alertsPath, alerts);
    await tester.tap(find.text('Tentar de novo'));
    await settle(tester);
    expect(find.text('Limite diário atingido'), findsOneWidget);
  });

  testWidgets('o atalho das preferencias abre a tela de preferencias', (WidgetTester tester) async {
    await pumpAlerts(tester);

    await tester.tap(find.byTooltip('Preferências de notificação'));
    await settle(tester);

    expect(find.text('Preferências de notificação'), findsOneWidget);
  });
}
