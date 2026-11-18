import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/activity_reports/activity_reports_module.dart';
import 'package:parentalynx/features/activity_reports/activity_reports_routes.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

/// Sessao de ontem (16/11) no horario do aparelho (UTC-3), independente do fuso do teste.
Map<String, Object?> _session(
  String package,
  String label,
  String category,
  String from,
  String to,
) {
  int at(String clock) {
    final List<String> parts = clock.split(':');
    return DateTime.utc(
      2026,
      11,
      16,
      int.parse(parts[0]) + 3,
      int.parse(parts[1]),
    ).millisecondsSinceEpoch;
  }

  return <String, Object?>{
    'package': package,
    'label': label,
    'category': category,
    'start': at(from),
    'end': at(to),
    'durationMs': at(to) - at(from),
    'tzOffsetMin': -180,
  };
}

Map<String, Object?> _event(
  int id,
  String type,
  Duration ago,
  Map<String, Object?> data, {
  String? label,
}) {
  return <String, Object?>{'id': id, 'type': type, 'ts': msAgo(ago), 'label': ?label, 'data': data};
}

Map<String, Object?> _page(
  int id,
  Duration ago,
  String url,
  String domain,
  String title, {
  String? reason,
}) {
  return <String, Object?>{
    'id': id,
    'ts': msAgo(ago),
    'url': url,
    'domain': domain,
    'title': title,
    'blocked': reason != null,
    'reason': ?reason,
  };
}

void main() {
  const String sessionsPath = '/v1/guardian/devices/$deviceId/sessions';
  const String eventsPath = '/v1/guardian/devices/$deviceId/events';
  const String browsingPath = '/v1/guardian/devices/$deviceId/browsing';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerActivityReportsModule(deps.di);
    installStandardRoutes(deps.backend);
    deps.backend
      ..onJson('GET', sessionsPath, <String, Object?>{
        'sessions': <Object?>[
          _session('com.whatsapp', 'WhatsApp', 'communication', '07:10', '07:25'),
          _session('com.google.android.youtube', 'YouTube', 'video', '07:26', '07:40'),
          _session('com.supercell.brawlstars', 'Brawl Stars', 'games', '12:30', '12:55'),
          _session('com.whatsapp', 'WhatsApp', 'communication', '12:56', '13:05'),
          _session('com.google.android.youtube', 'YouTube', 'video', '16:00', '16:45'),
          _session('com.duolingo', 'Duolingo', 'productivity', '16:46', '17:10'),
          _session('com.supercell.brawlstars', 'Brawl Stars', 'games', '19:00', '19:50'),
        ],
      })
      ..onJson('GET', eventsPath, <String, Object?>{
        'events': <Object?>[
          _event(8, 'blocked_attempt', const Duration(minutes: 5), <String, Object?>{
            'reason': 'app_blocked',
          }, label: 'TikTok'),
          _event(7, 'time_request', const Duration(minutes: 40), <String, Object?>{
            'minutes': 30,
            'message': 'Posso terminar o vídeo?',
          }),
          _event(6, 'low_time', const Duration(hours: 2), <String, Object?>{
            'remainingMs': 10 * 60000,
          }),
          _event(5, 'permission_changed', const Duration(hours: 4), <String, Object?>{
            'permission': 'accessibility',
            'granted': false,
          }),
          _event(4, 'lock_started', const Duration(hours: 18, minutes: 30), <String, Object?>{
            'reason': 'schedule',
            'releaseAt': msAgo(const Duration(hours: 8, minutes: 30)),
          }),
          _event(3, 'limit_reached', const Duration(hours: 19, minutes: 50), <String, Object?>{
            'quotaUsedMs': 150 * 60000,
          }),
          _event(
            2,
            'app_installed',
            const Duration(hours: 21, minutes: 20),
            <String, Object?>{},
            label: 'Roblox',
          ),
          _event(1, 'policy_applied', const Duration(hours: 30), <String, Object?>{'version': 12}),
        ],
        'nextBefore': null,
      })
      ..onJson('GET', browsingPath, <String, Object?>{
        'entries': <Object?>[
          _page(
            5,
            const Duration(minutes: 10),
            'https://www.manualdomundo.com.br/slime',
            'manualdomundo.com.br',
            'Como fazer slime caseiro',
          ),
          _page(
            4,
            const Duration(minutes: 25),
            'https://apostas.exemplo/cassino',
            'apostas.exemplo',
            '',
            reason: 'category',
          ),
          _page(
            3,
            const Duration(hours: 1),
            'https://pt.wikipedia.org/wiki/Lince',
            'pt.wikipedia.org',
            'Lince – Wikipédia',
          ),
          _page(
            2,
            const Duration(hours: 20),
            'https://chat.exemplo/sala',
            'chat.exemplo',
            'Chat anônimo',
            reason: 'domain_blocked',
          ),
          _page(
            1,
            const Duration(hours: 22),
            'https://escola.exemplo/tarefas',
            'escola.exemplo',
            'Tarefas da semana',
          ),
        ],
        'nextBefore': 'c1',
      });
  });

  tearDown(() => deps.dispose());

  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    Size size = phoneSize,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpGuardianRoutes(
      tester,
      routes: activityReportsRoutes(deps.di),
      location: location,
      deps: deps,
      size: size,
      brightness: brightness,
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  Future<void> pumpLargeText(WidgetTester tester, String location, double height) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAt(tester, location, size: Size(392, height));
  }

  final String timeline = ReportsPaths.sessionsOf('2026-11-16');
  final String events = ReportsPaths.eventsIn('2026-11-11', fixtureToday);
  final String browsing = ReportsPaths.browsingIn('2026-11-11', fixtureToday);

  group('linha do tempo', () {
    const Size size = Size(392, 1250);

    testWidgets('dia com resumo, faixa de 24 horas e pausas', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, timeline, size: size);

      expect(find.text('João'), findsOneWidget);
      expect(find.text('Ontem'), findsOneWidget);
      expect(find.text('3h 2min'), findsOneWidget);
      expect(find.text('Sem uso por 4h 50min, das 07:40 às 12:30'), findsOneWidget);
      expect(find.text('Primeiro uso às 07:10 e último às 19:50.'), findsOneWidget);
      await expectScreenshot(tester, 'reports_linha_do_tempo');
    });

    testWidgets('no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
      await pumpAt(tester, timeline, size: size, brightness: Brightness.dark);
      await expectScreenshot(tester, 'reports_linha_do_tempo_escuro');
    });

    testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pumpAt(tester, timeline, size: size);
      await expectAccessible(tester);
    });

    testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      await pumpLargeText(tester, timeline, 3600);
      expect(tester.takeException(), isNull);
    });

    testWidgets('voltar para hoje consulta o dia corrente', (WidgetTester tester) async {
      await pumpAt(tester, timeline, size: size);

      await tester.tap(find.text('Voltar para hoje'));
      await settle(tester);

      expect(deps.backend.calls('GET', sessionsPath).last.url.queryParameters['day'], fixtureToday);
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Voltar para hoje'), findsNothing);
    });
  });

  group('eventos', () {
    const Size size = Size(392, 1200);

    testWidgets('por dia, em palavras simples e com o período visível', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, events, size: size);

      expect(find.text('11/11 a 17/11 · 7 dias'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Ontem'), findsOneWidget);
      expect(find.text('Tentou abrir TikTok'), findsOneWidget);
      expect(find.text('Bloqueio iniciado'), findsOneWidget);
      expect(find.text('Serviço de acessibilidade: revogada'), findsOneWidget);
      await expectScreenshot(tester, 'reports_eventos');
    });

    testWidgets('no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
      await pumpAt(tester, events, size: size, brightness: Brightness.dark);
      await expectScreenshot(tester, 'reports_eventos_escuro');
    });

    testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pumpAt(tester, events, size: size);
      await expectAccessible(tester);
    });

    testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      await pumpLargeText(tester, events, 3600);
      expect(tester.takeException(), isNull);
    });
  });

  group('histórico de navegação', () {
    const Size size = Size(392, 1180);

    testWidgets('explica a privacidade e mostra o motivo dos bloqueios', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, browsing, size: size);

      expect(find.text('Só o navegador ParentaLynx'), findsOneWidget);
      expect(find.text('Categoria bloqueada'), findsOneWidget);
      expect(find.text('Site bloqueado'), findsOneWidget);
      expect(find.text('Carregar mais antigos'), findsOneWidget);
      await expectScreenshot(tester, 'reports_navegacao');
    });

    testWidgets('no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
      await pumpAt(tester, browsing, size: size, brightness: Brightness.dark);
      await expectScreenshot(tester, 'reports_navegacao_escuro');
    });

    testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pumpAt(tester, browsing, size: size);
      await expectAccessible(tester);
    });

    testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      await pumpLargeText(tester, browsing, 4200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('busca e filtro valem para as páginas carregadas', (WidgetTester tester) async {
      await pumpAt(tester, browsing, size: size);

      await tester.enterText(find.byType(TextField), 'wiki');
      await settle(tester);
      expect(find.text('Lince – Wikipédia'), findsOneWidget);
      expect(find.text('Como fazer slime caseiro'), findsNothing);

      await tester.enterText(find.byType(TextField), 'xyz');
      await settle(tester);
      expect(find.text('Nada encontrado para "xyz"'), findsOneWidget);

      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.tap(find.text('Bloqueadas'));
      await settle(tester);
      expect(find.text('Chat anônimo'), findsOneWidget);
      expect(find.text('Tarefas da semana'), findsNothing);
    });
  });
}
