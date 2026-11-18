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
import '../../../support/test_dependencies.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerBlockingModule(deps.di);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpBlocking(WidgetTester tester, {required String location}) {
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
      size: const Size(392, 1600),
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
      expect(find.text('Alterações não salvas'), findsNothing);

      await tester.enterText(find.byType(TextField), 'https://www.Jogos.com/inicio');
      await tester.tap(find.byTooltip('Adicionar site'));
      await settle(tester);
      expect(find.text('jogos.com'), findsOneWidget);
      expect(find.text('Digite um endereço válido, por exemplo exemplo.com.br'), findsNothing);
      expect(find.text('Alterações não salvas'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'jogos.com');
      await tester.tap(find.byTooltip('Adicionar site'));
      await tester.pump();
      expect(find.text('Esse site já está na lista.'), findsOneWidget);

      final InputChip chip = tester.widget<InputChip>(find.widgetWithText(InputChip, 'jogos.com'));
      expect(chip.deleteButtonTooltipMessage, 'Remover jogos.com');
      chip.onDeleted!();
      await settle(tester);
      expect(find.text('Nenhum site bloqueado individualmente.'), findsOneWidget);
    });

    testWidgets('modo só autorizados troca as listas e avisa da lista vazia', (
      WidgetTester tester,
    ) async {
      installStandardRoutes(deps.backend);
      await pumpBlocking(tester, location: RulesPaths.web);

      expect(find.text('Categorias bloqueadas'), findsOneWidget);
      await tester.tap(find.text('Só autorizados'));
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
      final SwitchListTile uninstall = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Impedir a desinstalação do ParentaLynx'),
      );
      expect(uninstall.onChanged, isNull);

      await tester.tap(find.text('Bloquear se a proteção for desativada'));
      await settle(tester);
      expect(find.text('Alterações não salvas'), findsOneWidget);
    });

    testWidgets('dispositivo gerenciado libera as travas do sistema', (WidgetTester tester) async {
      installStandardRoutes(deps.backend, device: deviceJson(managementMode: 'device_owner'));
      await pumpBlocking(tester, location: RulesPaths.protection);

      expect(find.text('Aplicadas pelo próprio Android neste aparelho.'), findsOneWidget);
      await tester.tap(find.text('Impedir a depuração USB'));
      await settle(tester);
      expect(find.text('Alterações não salvas'), findsOneWidget);
    });
  });
}
