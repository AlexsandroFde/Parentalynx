import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_policy/device_policy_routes.dart';
import 'package:parentalynx/features/schedules/presentation/overview/schedule_rule_groups.dart';
import 'package:parentalynx/features/schedules/schedules_module.dart';
import 'package:parentalynx/features/schedules/schedules_routes.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerSchedulesModule(deps.di);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpSchedules(WidgetTester tester, {required String location}) {
    return pumpGuardianRoutes(
      tester,
      routes: <RouteBase>[
        rulesOverviewRoute(
          deps.di,
          groups: scheduleRuleGroups,
          routes: scheduleRuleRoutes(deps.di),
        ),
      ],
      location: location,
      deps: deps,
      size: const Size(392, 1100),
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  testWidgets('períodos de bloqueio: sugestão cria um período no rascunho', (
    WidgetTester tester,
  ) async {
    final Map<String, Object?> policy = policyJson()..['blockPeriods'] = <Object?>[];
    installStandardRoutes(deps.backend, policy: policy);
    await pumpSchedules(tester, location: RulesPaths.periods);

    expect(find.text('Nenhum período criado'), findsOneWidget);
    await tester.tap(find.text('Hora de dormir, 21:00 às 07:00'));
    await settle(tester);

    expect(find.text('Todos os dias, 21:00 às 07:00 do dia seguinte'), findsOneWidget);
    expect(find.text('Alterações não salvas'), findsOneWidget);
  });

  testWidgets('horários permitidos: ligar a restrição começa com um horário comum', (
    WidgetTester tester,
  ) async {
    installStandardRoutes(deps.backend);
    await pumpSchedules(tester, location: RulesPaths.hours);

    expect(find.text('Alterações não salvas'), findsNothing);
    await tester.tap(find.text('Restringir os horários de uso'));
    await settle(tester);

    expect(find.text('07:00 às 21:00'), findsWidgets);
    expect(find.text('Alterações não salvas'), findsOneWidget);
  });
}
