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
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  testWidgets('aplicativos: lista com estados e edição pela folha do app', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpApps(tester);

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

  testWidgets('exceções listam os apps liberados e as funções essenciais', (
    WidgetTester tester,
  ) async {
    await pumpApps(tester, location: RulesPaths.exceptions, size: const Size(392, 1300));

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Telefone'), findsOneWidget);
  });
}
