import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/activity_reports/activity_reports_module.dart';
import 'package:parentalynx/features/activity_reports/activity_reports_routes.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String summaryPath = '/v1/guardian/devices/$deviceId/reports/summary';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerActivityReportsModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpReports(WidgetTester tester, {Size size = const Size(392, 850)}) {
    return pumpGuardianRoutes(
      tester,
      routes: activityReportsRoutes(deps.di),
      location: GuardianPaths.reports,
      deps: deps,
      size: size,
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  testWidgets('relatório de 7 dias com resumo, gráficos e tabela', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpReports(tester, size: const Size(392, 2900));

    final Uri requested = deps.backend.calls('GET', summaryPath).single.url;
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
    deps.backend.on('GET', summaryPath, (http.Request request) {
      final Map<String, Object?> body = summaryJson();
      if (request.url.queryParameters['from'] == fixtureToday) {
        body['from'] = fixtureToday;
        body['daily'] = <Object?>[(body['daily']! as List<Object?>).last];
      }
      return jsonResponse(body);
    });
    await pumpReports(tester, size: const Size(392, 2400));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hoje'));
    await settle(tester);

    final Uri last = deps.backend.calls('GET', summaryPath).last.url;
    expect(last.queryParameters, <String, String>{'from': fixtureToday, 'to': fixtureToday});
    // Com um unico dia, os graficos por dia dao lugar ao resumo e as horas.
    expect(find.text('Uso por dia'), findsNothing);
    expect(find.text('Dentro do limite'), findsOneWidget);
    expect(find.text('Horários de maior atividade'), findsOneWidget);
  });

  testWidgets('período sem uso explica o estado vazio', (WidgetTester tester) async {
    deps.backend.onJson('GET', summaryPath, <String, Object?>{
      'from': '2026-11-11',
      'to': fixtureToday,
      'totals': <String, Object?>{'totalMs': 0},
      'daily': <Object?>[],
      'hourly': <int>[],
    });
    await pumpReports(tester, size: const Size(392, 1400));

    expect(find.text('Sem uso registrado neste período'), findsOneWidget);
    expect(find.text('Uso por aplicativo'), findsNothing);
  });

  testWidgets('falha ao carregar oferece tentar de novo', (WidgetTester tester) async {
    deps.backend.on('GET', summaryPath, (_) => errorResponse(500, 'internal'));
    await pumpReports(tester);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('sem aparelho vinculado oferece vincular', (WidgetTester tester) async {
    deps.backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{'devices': <Object?>[]});
    await pumpReports(tester);

    expect(find.text('Nenhum aparelho vinculado'), findsOneWidget);
    await tester.tap(find.text('Vincular aparelho'));
    await settle(tester);
    expect(find.text('destino ${GuardianPaths.pairing}'), findsOneWidget);
  });

  testWidgets('linha do tempo, eventos e navegação abrem pelos detalhes', (
    WidgetTester tester,
  ) async {
    deps.backend
      ..onJson('GET', '/v1/guardian/devices/$deviceId/sessions', <String, Object?>{
        'sessions': <Object?>[
          <String, Object?>{
            'package': 'com.whatsapp',
            'label': 'WhatsApp',
            'category': 'communication',
            'start': msAgo(const Duration(hours: 3)),
            'end': msAgo(const Duration(hours: 2, minutes: 40)),
            'durationMs': 20 * 60000,
            'tzOffsetMin': -180,
          },
        ],
      })
      ..onJson('GET', '/v1/guardian/devices/$deviceId/events', <String, Object?>{
        'events': <Object?>[
          <String, Object?>{
            'id': 1,
            'type': 'blocked_attempt',
            'ts': msAgo(const Duration(minutes: 5)),
            'label': 'TikTok',
            'data': <String, Object?>{'reason': 'app_blocked'},
          },
        ],
        'nextBefore': null,
      })
      ..onJson('GET', '/v1/guardian/devices/$deviceId/browsing', <String, Object?>{
        'entries': <Object?>[
          <String, Object?>{
            'id': 9,
            'ts': msAgo(const Duration(minutes: 8)),
            'url': 'https://apostas.exemplo',
            'domain': 'apostas.exemplo',
            'title': '',
            'blocked': true,
            'reason': 'category',
          },
        ],
      });
    final GoRouter router = await pumpReports(tester, size: const Size(392, 2900));

    await tester.tap(find.text('Linha do tempo das sessões'));
    await settle(tester);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.textContaining('1 sessão, 20min de uso'), findsOneWidget);
    expect(
      deps.backend
          .calls('GET', '/v1/guardian/devices/$deviceId/sessions')
          .single
          .url
          .queryParameters['day'],
      fixtureToday,
    );
    router.pop();
    await settle(tester);

    await tester.tap(find.text('Eventos'));
    await settle(tester);
    expect(find.text('Tentou abrir TikTok'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bloqueios'));
    await settle(tester);
    expect(
      deps.backend
          .calls('GET', '/v1/guardian/devices/$deviceId/events')
          .last
          .url
          .queryParameters['types'],
      'blocked_attempt,lock_started,lock_ended',
    );
    router.pop();
    await settle(tester);

    await tester.tap(find.text('Histórico de navegação'));
    await settle(tester);
    expect(find.text('apostas.exemplo'), findsOneWidget);
    expect(find.text('Categoria bloqueada'), findsOneWidget);
  });
}
