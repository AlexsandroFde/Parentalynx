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
  const String eventsPath = '/v1/guardian/devices/$deviceId/events';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerActivityReportsModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpReports(
    WidgetTester tester, {
    Size size = phoneSize,
    Brightness brightness = Brightness.light,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: activityReportsRoutes(deps.di),
      location: GuardianPaths.reports,
      deps: deps,
      size: size,
      brightness: brightness,
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  const Size fullPage = Size(392, 2900);

  testWidgets(
    'relatório de 7 dias: resumo primeiro, gráficos e listas com o valor exato',
    tags: 'screenshot',
    (WidgetTester tester) async {
      await pumpReports(tester, size: fullPage);

      final Uri requested = deps.backend.calls('GET', summaryPath).single.url;
      expect(requested.queryParameters, <String, String>{'from': '2026-11-11', 'to': '2026-11-17'});
      // Contexto sempre visivel: crianca, aparelho, periodo e de quando sao os dados.
      expect(find.text('João'), findsOneWidget);
      expect(find.text('Moto G de João'), findsOneWidget);
      expect(find.text('11/11 a 17/11 · 7 dias'), findsOneWidget);
      expect(find.text('Dados recebidos do aparelho há 1 min.'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('report-total')), findsOneWidget);
      expect(find.text('14h 40min'), findsOneWidget);
      expect(find.text('Uso por dia'), findsOneWidget);
      expect(find.text('Mais uso em seg 16/11, 4h. Média de 2h 6min por dia.'), findsOneWidget);
      expect(find.text('Horários de uso'), findsOneWidget);
      expect(find.text('Aplicativos mais usados'), findsOneWidget);
      expect(find.text('Por categoria'), findsOneWidget);
      expect(find.text('Apps bloqueados que tentou abrir'), findsOneWidget);
      // Os graficos que repetiam os mesmos dados sairam.
      expect(find.text('Evolução do uso'), findsNothing);
      await expectScreenshot(tester, 'reports_7_dias');

      // Os valores exatos de cada dia, sem depender do toque no grafico.
      await tester.tap(find.byTooltip('Ver valores').first);
      await settle(tester);
      expect(find.text('qua 11/11'), findsOneWidget);
      expect(find.text('no limite 2h 10min de 2h 30min · 2 bloqueios'), findsOneWidget);
    },
  );

  testWidgets('relatório no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
    await pumpReports(tester, size: fullPage, brightness: Brightness.dark);
    await expectScreenshot(tester, 'reports_7_dias_escuro');
  });

  testWidgets('relatório segue as diretrizes de acessibilidade', (WidgetTester tester) async {
    await pumpReports(tester, size: fullPage);
    await expectAccessible(tester);
  });

  testWidgets('relatório funciona com a fonte no maior tamanho', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpReports(tester, size: const Size(392, 6400));

    expect(tester.takeException(), isNull);
    expect(find.text('14h 40min'), findsOneWidget);
    // Com fonte grande, os atalhos de periodo quebram linha em vez de espremer.
    expect(find.widgetWithText(ChoiceChip, '30 dias'), findsOneWidget);
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
    await pumpReports(tester, size: fullPage);

    await tester.tap(find.text('Hoje'));
    await settle(tester);

    final Uri last = deps.backend.calls('GET', summaryPath).last.url;
    expect(last.queryParameters, <String, String>{'from': fixtureToday, 'to': fixtureToday});
    expect(find.text('Hoje, ter 17/11'), findsOneWidget);
    // Com um unico dia, o grafico por dia da lugar ao limite do dia e as horas.
    expect(find.text('Uso por dia'), findsNothing);
    expect(find.text('Conta no limite'), findsOneWidget);
    expect(find.text('Limite do dia'), findsOneWidget);
    expect(find.text('Horários de uso'), findsOneWidget);
  });

  testWidgets('falha ao trocar o período mantém o anterior e diz qual está na tela', (
    WidgetTester tester,
  ) async {
    await pumpReports(tester, size: fullPage);
    deps.backend.on('GET', summaryPath, (_) => errorResponse(500, 'internal'));

    await tester.tap(find.text('Ontem'));
    await settle(tester);

    expect(find.text('Não foi possível atualizar o relatório'), findsOneWidget);
    expect(find.textContaining('Mostrando 11/11 a 17/11'), findsOneWidget);
    expect(find.text('14h 40min'), findsOneWidget);
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
    expect(find.text('Aplicativos mais usados'), findsNothing);
    expect(find.text('Detalhes do período'), findsOneWidget);
  });

  testWidgets('falha ao carregar diz o que falhou e oferece tentar de novo', (
    WidgetTester tester,
  ) async {
    deps.backend.on('GET', summaryPath, (_) => errorResponse(500, 'internal'));
    await pumpReports(tester);

    expect(find.text('Não foi possível carregar o relatório'), findsOneWidget);
    deps.backend.onJson('GET', summaryPath, summaryJson());
    await tester.tap(find.text('Tentar de novo'));
    await settle(tester);
    expect(find.text('14h 40min'), findsOneWidget);
  });

  testWidgets('sem aparelho vinculado oferece vincular', (WidgetTester tester) async {
    deps.backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{'devices': <Object?>[]});
    await pumpReports(tester);

    expect(find.text('Nenhum aparelho vinculado'), findsOneWidget);
    await tester.tap(find.text('Vincular aparelho'));
    await settle(tester);
    expect(find.text('destino ${GuardianPaths.pairing}'), findsOneWidget);
  });

  testWidgets('tentativas bloqueadas levam aos eventos de bloqueio do mesmo período', (
    WidgetTester tester,
  ) async {
    deps.backend.onJson('GET', eventsPath, <String, Object?>{
      'events': <Object?>[],
      'nextBefore': null,
    });
    await pumpReports(tester, size: fullPage);

    await tester.tap(find.text('Ver eventos'));
    await settle(tester);

    final Uri request = deps.backend.calls('GET', eventsPath).single.url;
    expect(request.queryParameters['types'], 'blocked_attempt,lock_started,lock_ended');
    expect(request.queryParameters['from'], '2026-11-11');
    expect(find.text('Nenhum evento de bloqueios no período'), findsOneWidget);
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
      ..onJson('GET', eventsPath, <String, Object?>{
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
    final GoRouter router = await pumpReports(tester, size: fullPage);

    await tester.tap(find.text('Linha do tempo'));
    await settle(tester);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Sessão'), findsOneWidget);
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

    await tester.tap(find.text('Eventos do aparelho'));
    await settle(tester);
    expect(find.text('Tentou abrir TikTok'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bloqueios'));
    await settle(tester);
    expect(
      deps.backend.calls('GET', eventsPath).last.url.queryParameters['types'],
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
