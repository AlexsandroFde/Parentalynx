import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/app_management/app_management_module.dart';
import 'package:parentalynx/features/app_management/app_management_routes.dart';
import 'package:parentalynx/features/app_management/presentation/overview/app_management_rule_groups.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_policy/device_policy_routes.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerAppManagementModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpApps(
    WidgetTester tester, {
    String location = RulesPaths.apps,
    Size size = const Size(392, 1500),
    Brightness brightness = Brightness.light,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: <RouteBase>[
        rulesOverviewRoute(
          deps.di,
          groups: appManagementRuleGroups,
          routes: appManagementRuleRoutes(deps.di),
        ),
      ],
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

  final Finder unsaved = find.textContaining('Alterações não salvas');

  group('aplicativos', () {
    testWidgets('lista com estados e edição pela folha do app', (WidgetTester tester) async {
      await pumpApps(tester);

      expect(find.text('TikTok'), findsOneWidget);
      expect(find.text('Bloqueado'), findsOneWidget);
      expect(find.text('Exceção'), findsOneWidget);
      expect(find.text('Essencial'), findsOneWidget);
      expect(find.text('Bloqueados (1)'), findsOneWidget);
      // O identificador do pacote nao aparece na lista, so o nome do app.
      expect(find.textContaining('com.zhiliaoapp.musically'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('app-com.zhiliaoapp.musically')));
      await settle(tester);
      expect(find.text('Pode ser usado dentro do limite de tempo e dos horários.'), findsOneWidget);

      await tester.tap(find.text('Pode ser usado dentro do limite de tempo e dos horários.'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('app-rule-apply')));
      await settle(tester);

      expect(find.text('Bloqueado'), findsNothing);
      expect(unsaved, findsOneWidget);
    });

    testWidgets('limite próprio com atalho na folha do app', (WidgetTester tester) async {
      await pumpApps(tester);

      await tester.tap(find.byKey(const ValueKey<String>('app-com.duolingo')));
      await settle(tester);
      await tester.tap(find.text('Limite próprio para este app'));
      await tester.pump();
      await tester.tap(find.text('30min'));
      await tester.pump();
      expect(find.text('No máximo 30min por dia.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('app-rule-apply')));
      await settle(tester);

      expect(find.textContaining('limite 30min por dia'), findsOneWidget);
      expect(unsaved, findsOneWidget);
    });

    testWidgets('app essencial não pode ser alterado', (WidgetTester tester) async {
      await pumpApps(tester);

      await tester.tap(find.byKey(const ValueKey<String>('app-com.android.dialer')));
      await settle(tester);

      expect(find.text('Função essencial do sistema'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('app-rule-apply')), findsNothing);
    });

    testWidgets('categoria pedida no endereço já chega filtrada', (WidgetTester tester) async {
      await pumpApps(tester, location: RulesPaths.appsInCategory('browser'));

      expect(find.text('Chrome'), findsOneWidget);
      expect(find.text('TikTok'), findsNothing);
    });

    testWidgets('busca sem resultado oferece limpar os filtros', (WidgetTester tester) async {
      await pumpApps(tester);

      await tester.enterText(find.byType(TextField), 'nenhum app assim');
      await settle(tester);
      expect(find.text('Nenhum app encontrado'), findsOneWidget);

      await tester.tap(find.text('Limpar filtros'));
      await settle(tester);
      expect(find.text('TikTok'), findsOneWidget);
    });

    testWidgets('apps novos aguardando aparecem em destaque', (WidgetTester tester) async {
      installStandardRoutes(
        deps.backend,
        policy: policyJson(defaultForNewApps: 'blocked', rules: <String, Object?>{}),
      );
      await pumpApps(tester);

      expect(find.text('5 apps novos aguardam sua decisão'), findsOneWidget);
      await tester.tap(find.text('Ver apps novos'));
      await settle(tester);
      expect(find.text('Aguardando (5)'), findsOneWidget);
      expect(find.text('Chrome'), findsNothing);
    });

    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('aplicativos ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        await pumpApps(tester, brightness: brightness);
        await expectScreenshot(tester, 'rules_aplicativos_$theme');
      });
    }

    testWidgets('folha do app', tags: 'screenshot', (WidgetTester tester) async {
      await pumpApps(tester, size: const Size(392, 1100));
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('app-com.google.android.youtube')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('app-com.google.android.youtube')));
      await settle(tester);
      await expectScreenshot(tester, 'rules_aplicativos_folha');
      await expectAccessible(tester);
    });

    testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pumpApps(tester);
      await expectAccessible(tester);
    });

    testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApps(tester, size: const Size(392, 4000));
      expect(tester.takeException(), isNull);
      expect(find.text('Aguardando aprovação'), findsNothing);
      expect(find.text('Bloqueado'), findsOneWidget);
    });
  });

  group('exceções', () {
    testWidgets('listam os apps liberados e as funções essenciais', (WidgetTester tester) async {
      await pumpApps(tester, location: RulesPaths.exceptions, size: const Size(392, 1300));

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Chamadas de emergência'), findsOneWidget);

      await tester.tap(find.text('Itens essenciais deste aparelho'));
      await settle(tester);
      expect(find.text('Telefone'), findsWidgets);
    });

    testWidgets('tirar das exceções pode ser desfeito', (WidgetTester tester) async {
      await pumpApps(tester, location: RulesPaths.exceptions, size: const Size(392, 1300));

      await tester.tap(find.byTooltip('Tirar WhatsApp das exceções'));
      await settle(tester);
      expect(find.text('Nenhum app liberado'), findsOneWidget);
      expect(unsaved, findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await settle(tester);
      expect(find.byTooltip('Tirar WhatsApp das exceções'), findsOneWidget);
      expect(unsaved, findsNothing);
    });

    testWidgets('com alterações pendentes, não abre a lista de apps', (WidgetTester tester) async {
      final GoRouter router = await pumpApps(
        tester,
        location: RulesPaths.exceptions,
        size: const Size(392, 1300),
      );

      await tester.tap(find.byTooltip('Tirar WhatsApp das exceções'));
      await settle(tester);
      await tester.tap(find.text('Escolher apps'));
      await settle(tester);

      expect(router.state.uri.path, RulesPaths.exceptions);
      expect(
        find.text('Salve ou descarte as alterações antes de abrir a lista de apps.'),
        findsOneWidget,
      );
    });

    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('exceções ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        await pumpApps(
          tester,
          location: RulesPaths.exceptions,
          size: const Size(392, 1300),
          brightness: brightness,
        );
        await expectScreenshot(tester, 'rules_excecoes_$theme');
      });
    }

    testWidgets('exceções seguem as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pumpApps(tester, location: RulesPaths.exceptions, size: const Size(392, 1300));
      await expectAccessible(tester);
    });

    testWidgets('exceções funcionam com a fonte no maior tamanho', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApps(tester, location: RulesPaths.exceptions, size: const Size(392, 3200));
      expect(tester.takeException(), isNull);
    });
  });
}
