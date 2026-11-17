import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/features/guardian/dashboard/presentation/dashboard_page.dart';
import 'package:parentalynx/features/guardian/guardian_paths.dart';
import 'package:parentalynx/features/guardian/reports/reports_routes.dart';

import '../../../support/test_app.dart';
import 'support/guardian_fixtures.dart';

List<RouteBase> _routes() {
  return <RouteBase>[
    GoRoute(
      path: GuardianPaths.home,
      builder: (BuildContext context, GoRouterState state) => DashboardPage(now: fixtureNow),
    ),
    ...reportsRoutes,
  ];
}

void main() {
  testWidgets('mostra o tempo de hoje, o estado e os apps mais usados', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi(standardRoutes());
    await pumpGuardianRoutes(
      tester,
      routes: _routes(),
      location: GuardianPaths.home,
      overrides: api.overrides,
      size: const Size(392, 1500),
    );

    expect(find.text('João'), findsWidgets);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Regras aplicadas no aparelho'), findsOneWidget);
    // Limite de 2h30 com 1h10 usados: restam 1h20.
    expect(find.text('1h 20min'), findsOneWidget);
    expect(find.text('restante hoje'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Tentativa de abrir app bloqueado'), findsOneWidget);
    expect(find.text('Não garantido'), findsOneWidget);
  });

  testWidgets('tempo extra envia o comando e confirma', (WidgetTester tester) async {
    const String route = 'POST /v1/guardian/devices/$deviceId/extra-time';
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      route: (http.Request request) => <String, Object?>{
        'policyVersion': 13,
        'policy': policyJson(),
      },
    });
    await pumpGuardianRoutes(
      tester,
      routes: _routes(),
      location: GuardianPaths.home,
      overrides: api.overrides,
      size: const Size(392, 1500),
    );

    await tester.tap(find.widgetWithText(ActionChip, '30min'));
    await settle(tester);

    expect(api.bodyOf(api.calls(route).single), <String, Object?>{'minutes': 30});
    expect(find.text('30min a mais enviados para João.'), findsOneWidget);
  });

  testWidgets('pedido de tempo pendente leva aos alertas', (WidgetTester tester) async {
    final FakeApi api = FakeApi(standardRoutes(device: deviceJson(pendingTimeRequests: 1)));
    await pumpGuardianRoutes(
      tester,
      routes: _routes(),
      location: GuardianPaths.home,
      overrides: api.overrides,
      size: const Size(392, 1500),
    );

    expect(find.text('João pediu mais tempo'), findsOneWidget);
    await tester.tap(find.text('Ver pedidos'));
    await settle(tester);

    expect(find.text('destino ${GuardianPaths.alerts}'), findsOneWidget);
  });

  testWidgets('proteção degradada aparece como aviso', (WidgetTester tester) async {
    final FakeApi api = FakeApi(
      standardRoutes(device: deviceJson(issues: <String>['accessibility_disabled'])),
    );
    await pumpGuardianRoutes(
      tester,
      routes: _routes(),
      location: GuardianPaths.home,
      overrides: api.overrides,
      size: const Size(392, 1500),
    );

    expect(find.text('Serviço de acessibilidade desativado'), findsOneWidget);
  });

  group('capturas', () {
    testWidgets('painel liberado', tags: 'screenshot', (WidgetTester tester) async {
      final FakeApi api = FakeApi(standardRoutes());
      await pumpGuardianRoutes(
        tester,
        routes: _routes(),
        location: GuardianPaths.home,
        overrides: api.overrides,
        size: const Size(392, 1700),
      );
      await expectScreenshot(tester, 'dashboard_liberado');
    });

    testWidgets('painel bloqueado pelo limite', tags: 'screenshot', (WidgetTester tester) async {
      final FakeApi api = FakeApi(
        standardRoutes(
          device: deviceJson(
            lockState: 'daily_limit',
            releaseAt: DateTime(2026, 11, 18).millisecondsSinceEpoch,
            quotaUsedMs: 9000000,
            totalUsedMs: 9600000,
          ),
        ),
      );
      await pumpGuardianRoutes(
        tester,
        routes: _routes(),
        location: GuardianPaths.home,
        overrides: api.overrides,
        size: const Size(392, 1000),
      );
      expect(find.text('Limite diário atingido'), findsOneWidget);
      expect(find.text('Liberação prevista amanhã às 00:00.'), findsOneWidget);
      await expectScreenshot(tester, 'dashboard_bloqueado');
    });

    testWidgets('painel sem aparelho', tags: 'screenshot', (WidgetTester tester) async {
      final FakeApi api = FakeApi(<String, RouteHandler>{
        'GET /v1/guardian/devices': (http.Request r) => <String, Object?>{'devices': <Object?>[]},
      });
      await pumpGuardianRoutes(
        tester,
        routes: _routes(),
        location: GuardianPaths.home,
        overrides: api.overrides,
      );
      expect(find.text('Nenhum aparelho vinculado'), findsOneWidget);
      await tester.tap(find.text('Vincular aparelho'));
      await settle(tester);
      expect(find.text('destino ${GuardianPaths.pairing}'), findsOneWidget);
    });
  });
}
