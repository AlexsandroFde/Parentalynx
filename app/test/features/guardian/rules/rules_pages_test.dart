import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/features/guardian/guardian_paths.dart';
import 'package:parentalynx/features/guardian/rules/rules_paths.dart';
import 'package:parentalynx/features/guardian/rules/rules_routes.dart';

import '../../../support/test_app.dart';
import '../dashboard/support/guardian_fixtures.dart';

void main() {
  const String policyRoute = 'PUT /v1/guardian/devices/$deviceId/policy';

  testWidgets('visão geral resume cada grupo de regras', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi(standardRoutes());
    await pumpGuardianRoutes(
      tester,
      routes: rulesRoutes,
      location: GuardianPaths.rules,
      overrides: api.overrides,
      size: const Size(392, 1100),
    );

    expect(find.text('Regras de João'), findsOneWidget);
    expect(find.text('2h 30min por dia'), findsOneWidget);
    expect(find.text('1 ativo: Hora de dormir'), findsOneWidget);
    expect(find.text('1 bloqueado, 1 exceção, 1 com limite próprio'), findsOneWidget);
    await expectScreenshot(tester, 'rules_visao_geral');

    await tester.tap(find.text('Limite diário'));
    await settle(tester);
    expect(find.text('Limitar o tempo de uso por dia'), findsOneWidget);
  });

  testWidgets('limite diário: alterar mostra a barra de salvar e envia a versão base', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      policyRoute: (http.Request request) => <String, Object?>{
        'policyVersion': 13,
        'policy': api0PolicyFrom(request),
      },
    });
    await pumpGuardianRoutes(
      tester,
      routes: rulesRoutes,
      location: RulesPaths.limit,
      overrides: api.overrides,
      size: const Size(392, 1300),
    );

    expect(find.byKey(const ValueKey<String>('daily-limit-value')), findsOneWidget);
    expect(find.text('2h 30min'), findsOneWidget);
    expect(find.text('Alterações não salvas'), findsNothing);

    await tester.tap(find.text('Limite diferente por dia da semana'));
    await settle(tester);

    expect(find.text('Alterações não salvas'), findsOneWidget);
    expect(find.text('Sábado'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await settle(tester);

    final Map<String, Object?> body = api.bodyOf(api.calls(policyRoute).single);
    expect(body['baseVersion'], 12);
    final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
    final Map<String, Object?> limit = sent['dailyLimit']! as Map<String, Object?>;
    expect((limit['perWeekday']! as Map<String, Object?>)['6'], 150);
    expect(sent.containsKey('overrides'), isFalse);
    expect(find.text('Regras enviadas. Aguardando o aparelho confirmar.'), findsOneWidget);
    expect(find.text('Alterações não salvas'), findsNothing);
  });

  testWidgets('limite diário', tags: 'screenshot', (WidgetTester tester) async {
    final FakeApi api = FakeApi(standardRoutes());
    await pumpGuardianRoutes(
      tester,
      routes: rulesRoutes,
      location: RulesPaths.limit,
      overrides: api.overrides,
      size: const Size(392, 1000),
    );
    await expectScreenshot(tester, 'rules_limite_diario');
  });

  testWidgets('aplicativos: lista com estados e edição pela folha do app', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi(standardRoutes());
    await pumpGuardianRoutes(
      tester,
      routes: rulesRoutes,
      location: RulesPaths.apps,
      overrides: api.overrides,
      size: const Size(392, 1500),
    );

    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Bloqueado'), findsOneWidget);
    expect(find.text('Exceção'), findsOneWidget);
    expect(find.text('Essencial'), findsOneWidget);
    await expectScreenshot(tester, 'rules_aplicativos');

    await tester.tap(find.byKey(const ValueKey<String>('app-com.zhiliaoapp.musically')));
    await settle(tester);
    expect(find.text('Pode ser usado dentro do limite de tempo e dos horários.'), findsOneWidget);

    await tester.tap(find.text('Pode ser usado dentro do limite de tempo e dos horários.'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('app-rule-apply')));
    await settle(tester);

    expect(find.text('Bloqueado'), findsNothing);
    expect(find.text('Alterações não salvas'), findsOneWidget);
  });

  testWidgets('app essencial não pode ser alterado', (WidgetTester tester) async {
    final FakeApi api = FakeApi(standardRoutes());
    await pumpGuardianRoutes(
      tester,
      routes: rulesRoutes,
      location: RulesPaths.apps,
      overrides: api.overrides,
      size: const Size(392, 1500),
    );

    await tester.tap(find.byKey(const ValueKey<String>('app-com.android.dialer')));
    await settle(tester);

    expect(find.text('Função essencial do sistema'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('app-rule-apply')), findsNothing);
  });

  testWidgets('períodos de bloqueio: sugestão cria um período no rascunho', (
    WidgetTester tester,
  ) async {
    final Map<String, Object?> policy = policyJson()..['blockPeriods'] = <Object?>[];
    final FakeApi api = FakeApi(standardRoutes(policy: policy));
    await pumpGuardianRoutes(
      tester,
      routes: rulesRoutes,
      location: RulesPaths.periods,
      overrides: api.overrides,
      size: const Size(392, 1100),
    );

    expect(find.text('Nenhum período criado'), findsOneWidget);
    await tester.tap(find.text('Hora de dormir, 21:00 às 07:00'));
    await settle(tester);

    expect(find.text('Todos os dias, 21:00 às 07:00 do dia seguinte'), findsOneWidget);
    expect(find.text('Alterações não salvas'), findsOneWidget);
  });
}

/// Devolve a politica enviada no corpo, com os comandos vazios, como o servidor faria.
Map<String, Object?> api0PolicyFrom(http.Request request) {
  final Map<String, Object?> sent =
      FakeApi(<String, RouteHandler>{}).bodyOf(request)['policy']! as Map<String, Object?>;
  return <String, Object?>{...sent, 'overrides': policyJson()['overrides']};
}
