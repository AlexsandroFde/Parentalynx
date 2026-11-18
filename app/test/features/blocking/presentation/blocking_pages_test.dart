import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/blocking/blocking_module.dart';
import 'package:parentalynx/features/blocking/blocking_routes.dart';
import 'package:parentalynx/features/blocking/presentation/overview/blocking_rule_groups.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_policy/device_policy_routes.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerBlockingModule(deps.di);
  });

  tearDown(() => deps.dispose());

  final Finder unsaved = find.textContaining('Alterações não salvas');

  Future<GoRouter> pumpBlocking(
    WidgetTester tester, {
    required String location,
    Size size = const Size(392, 2400),
    Brightness brightness = Brightness.light,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: <RouteBase>[
        rulesOverviewRoute(
          deps.di,
          groups: blockingRuleGroups,
          routes: <RouteBase>[
            ...blockingRuleRoutes(deps.di),
            // Destino do atalho para os navegadores instalados (pagina de outra funcionalidade).
            GoRoute(
              path: 'apps',
              builder: (BuildContext context, GoRouterState state) {
                return Scaffold(body: Text('apps ${state.uri.queryParameters['category']}'));
              },
            ),
          ],
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

  group('navegação na internet', () {
    testWidgets('site digitado é conferido antes de entrar na lista', (WidgetTester tester) async {
      installStandardRoutes(deps.backend);
      await pumpBlocking(tester, location: RulesPaths.web);

      expect(find.text('Nenhum site bloqueado individualmente.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nao e site');
      await tester.tap(find.byTooltip('Adicionar site'));
      await tester.pump();
      expect(find.text('Digite um endereço válido, por exemplo exemplo.com.br'), findsOneWidget);
      expect(unsaved, findsNothing);

      await tester.enterText(find.byType(TextField), 'https://www.Jogos.com/inicio');
      await tester.tap(find.byTooltip('Adicionar site'));
      await settle(tester);
      expect(find.text('jogos.com'), findsOneWidget);
      expect(find.text('Digite um endereço válido, por exemplo exemplo.com.br'), findsNothing);
      expect(unsaved, findsOneWidget);

      await tester.enterText(find.byType(TextField), 'jogos.com');
      await tester.tap(find.byTooltip('Adicionar site'));
      await tester.pump();
      expect(find.text('Esse site já está na lista.'), findsOneWidget);

      await tester.tap(find.byTooltip('Remover jogos.com'));
      await settle(tester);
      expect(find.text('Nenhum site bloqueado individualmente.'), findsOneWidget);
      await tester.tap(find.text('Desfazer'));
      await settle(tester);
      expect(find.byTooltip('Remover jogos.com'), findsOneWidget);
    });

    testWidgets('modo só autorizados troca as listas e avisa da lista vazia', (
      WidgetTester tester,
    ) async {
      installStandardRoutes(deps.backend);
      await pumpBlocking(tester, location: RulesPaths.web);

      expect(find.text('Categorias bloqueadas'), findsOneWidget);
      await tester.tap(find.text('Só os sites que você autorizar'));
      await settle(tester);

      expect(find.text('Categorias bloqueadas'), findsNothing);
      expect(
        find.text('Nenhum site autorizado. Nesse modo, nada poderá ser aberto.'),
        findsOneWidget,
      );
      expect(find.text('Só os sites da lista de autorizados podem ser abertos.'), findsOneWidget);
    });

    testWidgets('ver navegadores abre os apps filtrados pela categoria', (
      WidgetTester tester,
    ) async {
      installStandardRoutes(deps.backend);
      final GoRouter router = await pumpBlocking(tester, location: RulesPaths.web);

      await tester.tap(find.text('Ver navegadores instalados'));
      await settle(tester);

      expect(find.text('apps browser'), findsOneWidget);
      expect(router.state.uri.toString(), RulesPaths.appsInCategory('browser'));
    });
  });

  group('proteção', () {
    testWidgets('modo comum explica que as travas exigem dispositivo gerenciado', (
      WidgetTester tester,
    ) async {
      installStandardRoutes(deps.backend);
      await pumpBlocking(tester, location: RulesPaths.protection);

      expect(find.text('Disponíveis só no modo dispositivo gerenciado.'), findsOneWidget);
      // Sem dispositivo gerenciado as travas nao aparecem como ligadas: so a explicacao.
      expect(find.text('Impedir a desinstalação do ParentaLynx'), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
      await tester.tap(find.text('Ver o que as travas fazem'));
      await settle(tester);
      expect(find.text('Impedir a desinstalação do ParentaLynx'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await settle(tester);

      await tester.tap(find.text('Bloquear se a proteção for desativada'));
      await settle(tester);
      expect(unsaved, findsOneWidget);
    });

    testWidgets('dispositivo gerenciado libera as travas do sistema', (WidgetTester tester) async {
      installStandardRoutes(deps.backend, device: deviceJson(managementMode: 'device_owner'));
      await pumpBlocking(tester, location: RulesPaths.protection);

      expect(find.text('Aplicadas pelo próprio Android neste aparelho.'), findsOneWidget);
      await tester.tap(find.text('Impedir a depuração USB'));
      await settle(tester);
      expect(unsaved, findsOneWidget);
    });
  });

  group('aparência', () {
    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('navegação ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        installStandardRoutes(deps.backend);
        await pumpBlocking(
          tester,
          location: RulesPaths.web,
          size: const Size(392, 2000),
          brightness: brightness,
        );
        await expectScreenshot(tester, 'rules_navegacao_$theme');
      });

      testWidgets('proteção ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        installStandardRoutes(deps.backend);
        await pumpBlocking(
          tester,
          location: RulesPaths.protection,
          size: const Size(392, 1500),
          brightness: brightness,
        );
        await expectScreenshot(tester, 'rules_protecao_$theme');
      });
    }

    testWidgets('proteção com dispositivo gerenciado', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      installStandardRoutes(deps.backend, device: deviceJson(managementMode: 'device_owner'));
      await pumpBlocking(tester, location: RulesPaths.protection, size: const Size(392, 1900));
      await expectScreenshot(tester, 'rules_protecao_gerenciado');
    });

    for (final String location in <String>[RulesPaths.web, RulesPaths.protection]) {
      testWidgets('$location segue as diretrizes de acessibilidade', (WidgetTester tester) async {
        installStandardRoutes(deps.backend);
        await pumpBlocking(tester, location: location, size: const Size(392, 2000));
        await expectAccessible(tester);
      });

      testWidgets('$location funciona com a fonte no maior tamanho', (WidgetTester tester) async {
        installStandardRoutes(deps.backend, device: deviceJson(managementMode: 'device_owner'));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpBlocking(tester, location: location, size: const Size(392, 5000));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
