import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_policy/device_policy_routes.dart';
import 'package:parentalynx/features/screen_time/presentation/overview/screen_time_rule_groups.dart';
import 'package:parentalynx/features/screen_time/screen_time_module.dart';
import 'package:parentalynx/features/screen_time/screen_time_routes.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String detailPath = '/v1/guardian/devices/$deviceId';
  const String policyPath = '/v1/guardian/devices/$deviceId/policy';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerScreenTimeModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  Widget withDevices(Widget app) {
    return BlocProvider<DevicesBloc>(
      create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
      child: app,
    );
  }

  Future<GoRouter> pumpLimit(
    WidgetTester tester, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: <RouteBase>[
        rulesOverviewRoute(
          deps.di,
          groups: screenTimeRuleGroups,
          routes: screenTimeRuleRoutes(deps.di),
        ),
      ],
      location: RulesPaths.limit,
      deps: deps,
      size: size,
      brightness: brightness,
      wrap: withDevices,
    );
  }

  final Finder unsaved = find.textContaining('Alterações não salvas');

  void acceptSaves() {
    deps.backend.on('PUT', policyPath, (http.Request request) {
      final Map<String, Object?> body = jsonDecode(request.body) as Map<String, Object?>;
      final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
      return jsonResponse(<String, Object?>{
        'policyVersion': 13,
        'policy': <String, Object?>{...sent, 'overrides': policyJson()['overrides']},
      });
    });
  }

  group('limite diário', () {
    testWidgets('alterar mostra a barra de salvar, envia a versão base e fica pendente', (
      WidgetTester tester,
    ) async {
      acceptSaves();
      await pumpLimit(tester, size: const Size(392, 1400));

      expect(find.text('João · moto g54'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('daily-limit-value')), findsOneWidget);
      expect(find.text('Regras aplicadas no aparelho'), findsOneWidget);
      expect(unsaved, findsNothing);

      await tester.tap(find.text('Tempo diferente em alguns dias'));
      await settle(tester);

      expect(unsaved, findsOneWidget);
      expect(find.text('Sábado'), findsOneWidget);
      expect(find.text('Todos os dias: 2h 30min'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await settle(tester);

      final Map<String, Object?> body = deps.backend.lastBody('PUT', policyPath);
      expect(deps.backend.calls('PUT', policyPath), hasLength(1));
      expect(body['baseVersion'], 12);
      final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
      final Map<String, Object?> limit = sent['dailyLimit']! as Map<String, Object?>;
      expect((limit['perWeekday']! as Map<String, Object?>)['6'], 150);
      expect(sent.containsKey('overrides'), isFalse);
      expect(
        find.text('Alterações salvas. O aparelho de João aplica em instantes.'),
        findsOneWidget,
      );
      expect(unsaved, findsNothing);
      // A versao 13 ainda nao foi confirmada pelo aparelho: nunca aparece como aplicada.
      expect(find.text('Aguardando o aparelho confirmar'), findsOneWidget);
      expect(find.text('Regras aplicadas no aparelho'), findsNothing);
    });

    testWidgets('atalho de tempo troca o limite no rascunho', (WidgetTester tester) async {
      await pumpLimit(tester, size: const Size(392, 1400));

      await tester.tap(find.text('3h'));
      await settle(tester);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey<String>('daily-limit-value'))).data,
        '3h',
      );
      expect(unsaved, findsOneWidget);
    });

    testWidgets('falha ao salvar explica o que continua valendo e oferece tentar de novo', (
      WidgetTester tester,
    ) async {
      deps.backend.onError('PUT', policyPath, status: 500, code: 'internal');
      await pumpLimit(tester, size: const Size(392, 1400));

      await tester.tap(find.text('3h'));
      await settle(tester);
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(find.text('Não foi possível salvar'), findsOneWidget);
      expect(
        find.textContaining('as regras anteriores continuam valendo e as suas alterações'),
        findsOneWidget,
      );
      expect(find.text('Tentar de novo'), findsWidgets);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey<String>('daily-limit-value'))).data,
        '3h',
      );
    });

    testWidgets('conflito mostra a versão atual e permite refazer as alterações', (
      WidgetTester tester,
    ) async {
      bool conflicted = false;
      deps.backend
        ..on('GET', detailPath, (http.Request request) {
          return jsonResponse(<String, Object?>{
            'device': deviceJson(),
            'policyVersion': conflicted ? 13 : 12,
            'policy': policyJson(minutes: conflicted ? 60 : 150),
          });
        })
        ..on('PUT', policyPath, (http.Request request) {
          conflicted = true;
          return errorResponse(409, 'version_conflict');
        });
      await pumpLimit(tester, size: const Size(392, 1400));

      await tester.tap(find.text('3h'));
      await settle(tester);
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(find.text('As regras mudaram em outra sessão'), findsOneWidget);
      Text value() => tester.widget<Text>(find.byKey(const ValueKey<String>('daily-limit-value')));
      expect(value().data, '1h');
      expect(unsaved, findsNothing);

      await tester.tap(find.text('Refazer minhas alterações'));
      await settle(tester);
      expect(value().data, '3h');
      expect(unsaved, findsOneWidget);
    });

    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('limite diário ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        await pumpLimit(tester, size: const Size(392, 1300), brightness: brightness);
        await expectScreenshot(tester, 'rules_limite_diario_$theme');
      });
    }

    testWidgets('com alterações e limite por dia da semana', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      await pumpLimit(tester, size: const Size(392, 1500));
      await tester.tap(find.text('Tempo diferente em alguns dias'));
      await settle(tester);
      await expectScreenshot(tester, 'rules_limite_diario_semana');
    });

    testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pumpLimit(tester, size: const Size(392, 1300));
      await expectAccessible(tester);
    });

    testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLimit(tester, size: const Size(392, 3000));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tempo diferente em alguns dias'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('pedidos de tempo', () {
    const String listPath = '/v1/guardian/devices/$deviceId/time-requests';
    const String resolvePath = '/v1/guardian/time-requests/r1/resolve';

    Map<String, Object?> request({
      String id = 'r1',
      String status = 'pending',
      int? grantedMinutes,
      Duration ago = const Duration(minutes: 5),
    }) {
      return <String, Object?>{
        'id': id,
        'deviceId': deviceId,
        'childName': 'João',
        'createdAt': msAgo(ago),
        'minutes': 30,
        'message': 'Falta pouco para acabar o filme',
        'status': status,
        'grantedMinutes': ?grantedMinutes,
      };
    }

    Future<void> pumpRequests(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      Size size = phoneSize,
    }) async {
      await pumpGuardianRoutes(
        tester,
        routes: <RouteBase>[
          GoRoute(
            path: GuardianPaths.alerts,
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: Center(child: Text('alertas')));
            },
            routes: screenTimeAlertRoutes(deps.di),
          ),
        ],
        location: GuardianPaths.timeRequests,
        deps: deps,
        brightness: brightness,
        size: size,
        destinations: const <String>[GuardianPaths.pairing],
        wrap: withDevices,
      );
    }

    void installRequests() {
      deps.backend.onJson('GET', listPath, <String, Object?>{
        'requests': <Object?>[
          request(),
          request(id: 'r0', status: 'approved', grantedMinutes: 15, ago: const Duration(hours: 3)),
        ],
      });
    }

    testWidgets('aprovar pela folha concede os minutos escolhidos', (WidgetTester tester) async {
      deps.backend
        ..onJson('GET', listPath, <String, Object?>{
          'requests': <Object?>[request()],
        })
        ..onJson('POST', resolvePath, <String, Object?>{
          'request': request(status: 'approved', grantedMinutes: 45),
          'policyVersion': 13,
        });
      await pumpRequests(tester);

      expect(find.text('Aguardando resposta'), findsOneWidget);
      expect(find.text('"Falta pouco para acabar o filme"'), findsOneWidget);

      await tester.tap(find.text('Aprovar'));
      await settle(tester);
      expect(find.text('Quanto tempo conceder?'), findsOneWidget);
      expect(find.text('Conceder 30min'), findsOneWidget);

      await tester.tap(find.text('45min'));
      await tester.pump();
      await tester.tap(find.text('Conceder 45min'));
      await settle(tester);

      expect(deps.backend.lastBody('POST', resolvePath), <String, Object?>{
        'action': 'approve',
        'minutes': 45,
      });
      expect(
        find.text('45min a mais para João hoje. O aparelho recebe em instantes.'),
        findsOneWidget,
      );
      expect(find.text('Nenhum pedido aguardando resposta.'), findsOneWidget);
      expect(find.text('Respondidos'), findsOneWidget);
      expect(find.text('Aprovado: 45min'), findsOneWidget);
    });

    testWidgets('negar pede confirmação e não envia minutos', (WidgetTester tester) async {
      deps.backend
        ..onJson('GET', listPath, <String, Object?>{
          'requests': <Object?>[request()],
        })
        ..onJson('POST', resolvePath, <String, Object?>{'request': request(status: 'denied')});
      await pumpRequests(tester);

      await tester.tap(find.text('Negar'));
      await settle(tester);
      expect(find.text('Negar o pedido?'), findsOneWidget);
      expect(find.text('O limite de hoje continua o mesmo.'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Negar')));
      await settle(tester);

      expect(deps.backend.lastBody('POST', resolvePath), <String, Object?>{'action': 'deny'});
      expect(find.text('Pedido negado. João recebe o aviso.'), findsOneWidget);
    });

    testWidgets('sem pedidos mostra o vazio', (WidgetTester tester) async {
      deps.backend.onJson('GET', listPath, <String, Object?>{'requests': <Object?>[]});
      await pumpRequests(tester);

      expect(find.text('Nenhum pedido de tempo'), findsOneWidget);
    });

    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('pedidos de tempo ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        installRequests();
        await pumpRequests(tester, brightness: brightness);
        await expectScreenshot(tester, 'pedidos_de_tempo_$theme');
      });
    }

    testWidgets('pedidos seguem as diretrizes de acessibilidade', (WidgetTester tester) async {
      installRequests();
      await pumpRequests(tester);
      await expectAccessible(tester);
    });

    testWidgets('pedidos funcionam com a fonte no maior tamanho', (WidgetTester tester) async {
      installRequests();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpRequests(tester, size: const Size(392, 1900));
      expect(tester.takeException(), isNull);
      expect(find.text('Aprovar'), findsOneWidget);
    });
  });
}
