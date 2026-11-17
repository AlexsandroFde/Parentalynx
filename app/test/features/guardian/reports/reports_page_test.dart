import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/features/guardian/guardian_paths.dart';
import 'package:parentalynx/features/guardian/reports/reports_routes.dart';

import '../../../support/test_app.dart';
import '../dashboard/support/guardian_fixtures.dart';

void main() {
  const String summaryRoute = 'GET /v1/guardian/devices/$deviceId/reports/summary';

  testWidgets('relatório de 7 dias com resumo, gráficos e tabela', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi(standardRoutes());
    await pumpGuardianRoutes(
      tester,
      routes: reportsRoutes,
      location: GuardianPaths.reports,
      overrides: api.overrides,
      size: const Size(392, 2900),
    );

    final Uri requested = api.calls(summaryRoute).single.url;
    expect(requested.queryParameters, <String, String>{'from': '2026-11-11', 'to': '2026-11-17'});
    expect(find.byKey(const ValueKey<String>('report-total')), findsOneWidget);
    expect(find.text('14h 40min'), findsOneWidget);
    expect(find.text('Uso por dia'), findsOneWidget);
    expect(find.text('Horários de maior atividade'), findsOneWidget);
    expect(find.text('Evolução do uso'), findsOneWidget);
    expect(find.text('Tentativas de acesso bloqueadas'), findsOneWidget);
    expect(find.text('Tempo por categoria'), findsOneWidget);
    await expectScreenshot(tester, 'reports_7_dias');

    // A visao em tabela mostra os mesmos valores sem depender do toque no grafico.
    await tester.tap(find.byTooltip('Ver em tabela').first);
    await tester.pump();
    expect(find.text('No limite'), findsOneWidget);
    expect(find.text('qua 11/11'), findsOneWidget);
  });

  testWidgets('atalho Hoje consulta só o dia da cota do aparelho', (WidgetTester tester) async {
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      summaryRoute: (http.Request request) {
        final Map<String, Object?> body = summaryJson();
        if (request.url.queryParameters['from'] == fixtureToday) {
          body['from'] = fixtureToday;
          body['daily'] = <Object?>[(body['daily']! as List<Object?>).last];
        }
        return body;
      },
    });
    await pumpGuardianRoutes(
      tester,
      routes: reportsRoutes,
      location: GuardianPaths.reports,
      overrides: api.overrides,
      size: const Size(392, 2400),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hoje'));
    await settle(tester);

    final Uri last = api.calls(summaryRoute).last.url;
    expect(last.queryParameters, <String, String>{'from': fixtureToday, 'to': fixtureToday});
    // Com um unico dia, os graficos por dia dao lugar ao resumo e as horas.
    expect(find.text('Uso por dia'), findsNothing);
    expect(find.text('Dentro do limite'), findsOneWidget);
    expect(find.text('Horários de maior atividade'), findsOneWidget);
  });

  testWidgets('período sem uso explica o estado vazio', (WidgetTester tester) async {
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      summaryRoute: (http.Request request) => <String, Object?>{
        'from': '2026-11-11',
        'to': fixtureToday,
        'totals': <String, Object?>{'totalMs': 0},
        'daily': <Object?>[],
        'hourly': <int>[],
      },
    });
    await pumpGuardianRoutes(
      tester,
      routes: reportsRoutes,
      location: GuardianPaths.reports,
      overrides: api.overrides,
      size: const Size(392, 1400),
    );

    expect(find.text('Sem uso registrado neste período'), findsOneWidget);
    expect(find.text('Uso por aplicativo'), findsNothing);
  });

  testWidgets('falha ao carregar oferece tentar de novo', (WidgetTester tester) async {
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      summaryRoute: (http.Request request) => errorResponse('internal', 500),
    });
    await pumpGuardianRoutes(
      tester,
      routes: reportsRoutes,
      location: GuardianPaths.reports,
      overrides: api.overrides,
    );

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
