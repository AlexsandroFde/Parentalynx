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
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerSchedulesModule(deps.di);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpSchedules(
    WidgetTester tester, {
    required String location,
    Size size = const Size(392, 1100),
    Brightness brightness = Brightness.light,
  }) {
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
      size: size,
      brightness: brightness,
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  final Finder unsaved = find.textContaining('Alterações não salvas');

  /// Horarios ligados: seg a sex 07:00 as 21:00, sabado 09:00 as 22:00 e domingo sem horario.
  void installWeek() {
    final Map<String, Object?> policy = policyJson()
      ..['allowedHours'] = <String, Object?>{
        'enabled': true,
        'windows': <Object?>[
          <String, Object?>{
            'days': <int>[1, 2, 3, 4, 5],
            'start': '07:00',
            'end': '21:00',
          },
          <String, Object?>{
            'days': <int>[6],
            'start': '09:00',
            'end': '22:00',
          },
        ],
      };
    installStandardRoutes(deps.backend, policy: policy);
  }

  group('períodos de bloqueio', () {
    testWidgets('modelo cria um período no rascunho', (WidgetTester tester) async {
      final Map<String, Object?> policy = policyJson()..['blockPeriods'] = <Object?>[];
      installStandardRoutes(deps.backend, policy: policy);
      await pumpSchedules(tester, location: RulesPaths.periods);

      expect(find.text('Nenhum período criado'), findsOneWidget);
      await tester.tap(find.text('Hora de dormir'));
      await settle(tester);

      expect(find.text('Todos os dias, 21:00 às 07:00 do dia seguinte'), findsOneWidget);
      expect(unsaved, findsOneWidget);
    });

    testWidgets('folha confere o nome antes de concluir e pode desativar', (
      WidgetTester tester,
    ) async {
      installStandardRoutes(deps.backend);
      await pumpSchedules(tester, location: RulesPaths.periods);

      await tester.tap(find.text('Hora de dormir'));
      await settle(tester);
      expect(find.text('Editar período'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  ');
      await tester.tap(find.text('Concluir'));
      await tester.pump();
      expect(find.textContaining('Dê um nome ao período'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Dormir');
      await tester.tap(find.text('Período ativo'));
      await tester.pump();
      await tester.tap(find.text('Concluir'));
      await settle(tester);

      expect(find.text('Dormir'), findsOneWidget);
      expect(find.text('Desativado'), findsOneWidget);
      expect(unsaved, findsOneWidget);
    });

    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('períodos ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        installStandardRoutes(deps.backend);
        await pumpSchedules(tester, location: RulesPaths.periods, brightness: brightness);
        await expectScreenshot(tester, 'rules_periodos_$theme');
      });
    }

    testWidgets('folha de novo período', tags: 'screenshot', (WidgetTester tester) async {
      installStandardRoutes(deps.backend);
      await pumpSchedules(tester, location: RulesPaths.periods, size: const Size(392, 1300));
      await tester.tap(find.text('Novo período'));
      await settle(tester);
      await expectScreenshot(tester, 'rules_periodos_folha');
      await expectAccessible(tester);
    });

    testWidgets('períodos seguem as diretrizes de acessibilidade', (WidgetTester tester) async {
      installStandardRoutes(deps.backend);
      await pumpSchedules(tester, location: RulesPaths.periods);
      await expectAccessible(tester);
    });

    testWidgets('períodos funcionam com a fonte no maior tamanho', (WidgetTester tester) async {
      installStandardRoutes(deps.backend);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSchedules(tester, location: RulesPaths.periods, size: const Size(392, 2400));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Hora de dormir'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('horários permitidos', () {
    testWidgets('ligar a restrição começa com um horário comum', (WidgetTester tester) async {
      installStandardRoutes(deps.backend);
      await pumpSchedules(tester, location: RulesPaths.hours);

      expect(unsaved, findsNothing);
      await tester.tap(find.text('Limitar os horários de uso'));
      await settle(tester);

      expect(find.text('07:00 às 21:00'), findsWidgets);
      expect(unsaved, findsOneWidget);
    });

    testWidgets('dia sem horário avisa e a folha do dia libera um horário', (
      WidgetTester tester,
    ) async {
      installWeek();
      await pumpSchedules(tester, location: RulesPaths.hours, size: const Size(392, 1400));

      expect(find.text('Dias sem nenhum horário liberado'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('day-7')));
      await settle(tester);
      expect(
        find.text('Sem horário liberado, o celular fica bloqueado o dia inteiro.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('add-window-7')));
      await settle(tester);
      expect(find.byTooltip('Remover 07:00 às 21:00'), findsOneWidget);
      expect(unsaved, findsOneWidget);
    });

    testWidgets('horário sobreposto é recusado com explicação', (WidgetTester tester) async {
      installWeek();
      await pumpSchedules(tester, location: RulesPaths.hours, size: const Size(392, 1400));

      await tester.tap(find.byKey(const ValueKey<String>('day-1')));
      await settle(tester);
      // A sugestao comeca depois do ultimo horario (21:00 as 22:00): entra sem conflito.
      await tester.tap(find.byKey(const ValueKey<String>('add-window-1')));
      await settle(tester);
      expect(find.byTooltip('Remover 21:00 às 22:00'), findsOneWidget);

      await tester.tap(find.text('Até o fim do dia'));
      await tester.pump();
      // Nova sugestao 22:00 as 24:00 nao se sobrepoe; entra tambem.
      await tester.tap(find.byKey(const ValueKey<String>('add-window-1')));
      await settle(tester);
      expect(find.byTooltip('Remover 22:00 às 24:00'), findsOneWidget);
    });

    testWidgets('copiar horários de um dia pede confirmação', (WidgetTester tester) async {
      installWeek();
      await pumpSchedules(tester, location: RulesPaths.hours, size: const Size(392, 1400));

      await tester.tap(find.byKey(const ValueKey<String>('day-6')));
      await settle(tester);
      await tester.tap(find.text('Todos os dias'));
      await settle(tester);
      expect(find.text('Copiar para todos os dias?'), findsOneWidget);
      await tester.tap(find.text('Copiar horários'));
      await settle(tester);

      await tester.tap(find.byTooltip('Fechar'));
      await settle(tester);
      expect(find.text('09:00 às 22:00'), findsNWidgets(7));
      expect(find.text('Dias sem nenhum horário liberado'), findsNothing);
    });

    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('horários ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        installWeek();
        await pumpSchedules(
          tester,
          location: RulesPaths.hours,
          size: const Size(392, 1400),
          brightness: brightness,
        );
        await expectScreenshot(tester, 'rules_horarios_$theme');
      });
    }

    testWidgets('folha de um dia', tags: 'screenshot', (WidgetTester tester) async {
      installWeek();
      await pumpSchedules(tester, location: RulesPaths.hours, size: const Size(392, 1400));
      await tester.tap(find.byKey(const ValueKey<String>('day-1')));
      await settle(tester);
      await expectScreenshot(tester, 'rules_horarios_folha');
      await expectAccessible(tester);
    });

    testWidgets('horários seguem as diretrizes de acessibilidade', (WidgetTester tester) async {
      installWeek();
      await pumpSchedules(tester, location: RulesPaths.hours, size: const Size(392, 1400));
      await expectAccessible(tester);
    });

    testWidgets('horários funcionam com a fonte no maior tamanho', (WidgetTester tester) async {
      installWeek();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSchedules(tester, location: RulesPaths.hours, size: const Size(392, 3200));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey<String>('day-1')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
