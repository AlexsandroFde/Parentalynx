import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/app_management/app_management_module.dart';
import 'package:parentalynx/features/app_management/app_management_routes.dart';
import 'package:parentalynx/features/app_management/presentation/overview/app_management_rule_groups.dart';
import 'package:parentalynx/features/blocking/blocking_module.dart';
import 'package:parentalynx/features/blocking/blocking_routes.dart';
import 'package:parentalynx/features/blocking/presentation/overview/blocking_rule_groups.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_policy/device_policy_routes.dart';
import 'package:parentalynx/features/device_policy/presentation/overview/rule_group.dart';
import 'package:parentalynx/features/schedules/presentation/overview/schedule_rule_groups.dart';
import 'package:parentalynx/features/schedules/schedules_module.dart';
import 'package:parentalynx/features/schedules/schedules_routes.dart';
import 'package:parentalynx/features/screen_time/presentation/overview/screen_time_rule_groups.dart';
import 'package:parentalynx/features/screen_time/screen_time_module.dart';
import 'package:parentalynx/features/screen_time/screen_time_routes.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

/// Aba Regras montada como na composicao do app: a visao geral com os grupos e as paginas de
/// cada funcionalidade de regras abaixo dela.
void main() {
  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerScreenTimeModule(deps.di);
    registerSchedulesModule(deps.di);
    registerAppManagementModule(deps.di);
    registerBlockingModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpRules(WidgetTester tester, {required String location, required Size size}) {
    return pumpGuardianRoutes(
      tester,
      routes: <RouteBase>[
        rulesOverviewRoute(
          deps.di,
          groups: <RuleGroup>[
            ...screenTimeRuleGroups,
            ...scheduleRuleGroups,
            ...appManagementRuleGroups,
            ...blockingRuleGroups,
          ],
          routes: <RouteBase>[
            ...screenTimeRuleRoutes(deps.di),
            ...scheduleRuleRoutes(deps.di),
            ...appManagementRuleRoutes(deps.di),
            ...blockingRuleRoutes(deps.di),
          ],
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

  testWidgets('visão geral resume cada grupo de regras', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpRules(tester, location: GuardianPaths.rules, size: const Size(392, 1100));

    expect(find.text('Regras de João'), findsOneWidget);
    expect(find.text('2h 30min por dia'), findsOneWidget);
    expect(find.text('1 ativo: Hora de dormir'), findsOneWidget);
    expect(find.text('1 bloqueado, 1 exceção, 1 com limite próprio'), findsOneWidget);
    await expectScreenshot(tester, 'rules_visao_geral');

    await tester.tap(find.text('Limite diário'));
    await settle(tester);
    expect(find.text('Limitar o tempo de uso por dia'), findsOneWidget);
  });

  testWidgets('cada grupo abre a sua página', (WidgetTester tester) async {
    final GoRouter router = await pumpRules(
      tester,
      location: GuardianPaths.rules,
      size: const Size(392, 1100),
    );

    final Map<String, String> pages = <String, String>{
      'Horários permitidos': RulesPaths.hours,
      'Períodos de bloqueio': RulesPaths.periods,
      'Aplicativos': RulesPaths.apps,
      'Exceções e funções essenciais': RulesPaths.exceptions,
      'Navegação na internet': RulesPaths.web,
      'Proteção': RulesPaths.protection,
    };
    for (final MapEntry<String, String> page in pages.entries) {
      await tester.tap(find.text(page.key));
      await settle(tester);
      expect(router.state.uri.path, page.value, reason: page.key);
      router.pop();
      await settle(tester);
    }
  });

  testWidgets('sem aparelho vinculado oferece vincular', (WidgetTester tester) async {
    deps.backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{'devices': <Object?>[]});
    await pumpRules(tester, location: GuardianPaths.rules, size: const Size(392, 850));

    expect(find.text('Vincular aparelho'), findsOneWidget);
    await tester.tap(find.text('Vincular aparelho'));
    await settle(tester);
    expect(find.text('destino ${GuardianPaths.pairing}'), findsOneWidget);
  });
}
