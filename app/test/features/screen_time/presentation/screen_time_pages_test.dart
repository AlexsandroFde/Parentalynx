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

  Future<GoRouter> pumpLimit(WidgetTester tester, {required Size size}) {
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
      wrap: withDevices,
    );
  }

  testWidgets('limite diário: alterar mostra a barra de salvar e envia a versão base', (
    WidgetTester tester,
  ) async {
    deps.backend.on('PUT', policyPath, (http.Request request) {
      final Map<String, Object?> body = jsonDecode(request.body) as Map<String, Object?>;
      final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
      return jsonResponse(<String, Object?>{
        'policyVersion': 13,
        'policy': <String, Object?>{...sent, 'overrides': policyJson()['overrides']},
      });
    });
    await pumpLimit(tester, size: const Size(392, 1300));

    expect(find.byKey(const ValueKey<String>('daily-limit-value')), findsOneWidget);
    expect(find.text('2h 30min'), findsOneWidget);
    expect(find.text('Alterações não salvas'), findsNothing);

    await tester.tap(find.text('Limite diferente por dia da semana'));
    await settle(tester);

    expect(find.text('Alterações não salvas'), findsOneWidget);
    expect(find.text('Sábado'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await settle(tester);

    final Map<String, Object?> body = deps.backend.lastBody('PUT', policyPath);
    expect(deps.backend.calls('PUT', policyPath), hasLength(1));
    expect(body['baseVersion'], 12);
    final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
    final Map<String, Object?> limit = sent['dailyLimit']! as Map<String, Object?>;
    expect((limit['perWeekday']! as Map<String, Object?>)['6'], 150);
    expect(sent.containsKey('overrides'), isFalse);
    expect(find.text('Regras enviadas. Aguardando o aparelho confirmar.'), findsOneWidget);
    expect(find.text('Alterações não salvas'), findsNothing);
  });

  testWidgets('limite diário', tags: 'screenshot', (WidgetTester tester) async {
    await pumpLimit(tester, size: const Size(392, 1000));
    await expectScreenshot(tester, 'rules_limite_diario');
  });

  group('pedidos de tempo', () {
    const String listPath = '/v1/guardian/devices/$deviceId/time-requests';
    const String resolvePath = '/v1/guardian/time-requests/r1/resolve';

    Map<String, Object?> request({String status = 'pending', int? grantedMinutes}) {
      return <String, Object?>{
        'id': 'r1',
        'deviceId': deviceId,
        'childName': 'João',
        'createdAt': msAgo(const Duration(minutes: 5)),
        'minutes': 30,
        'message': 'Falta pouco para acabar o filme',
        'status': status,
        'grantedMinutes': ?grantedMinutes,
      };
    }

    Future<void> pumpRequests(WidgetTester tester) async {
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
        destinations: const <String>[GuardianPaths.pairing],
        wrap: withDevices,
      );
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
      expect(find.text('45min a mais para João.'), findsOneWidget);
      expect(find.text('Nenhum pedido aguardando resposta.'), findsOneWidget);
      expect(find.text('Respondidos'), findsOneWidget);
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
      await tester.tap(find.widgetWithText(FilledButton, 'Negar'));
      await settle(tester);

      expect(deps.backend.lastBody('POST', resolvePath), <String, Object?>{'action': 'deny'});
      expect(find.text('Pedido negado.'), findsOneWidget);
    });

    testWidgets('sem pedidos mostra o vazio', (WidgetTester tester) async {
      deps.backend.onJson('GET', listPath, <String, Object?>{'requests': <Object?>[]});
      await pumpRequests(tester);

      expect(find.text('Nenhum pedido de tempo'), findsOneWidget);
    });
  });
}
