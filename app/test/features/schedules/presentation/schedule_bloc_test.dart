import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/device_policy_module.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/presentation/editing/policy_section_state.dart';
import 'package:parentalynx/features/schedules/domain/entities/block_period_draft.dart';
import 'package:parentalynx/features/schedules/domain/entities/block_period_suggestion.dart';
import 'package:parentalynx/features/schedules/domain/entities/day_window.dart';
import 'package:parentalynx/features/schedules/domain/entities/schedule_rules.dart';
import 'package:parentalynx/features/schedules/domain/entities/schedule_section.dart';
import 'package:parentalynx/features/schedules/presentation/bloc/schedule/schedule_bloc.dart';
import 'package:parentalynx/features/schedules/schedules_module.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String policyPath = '/v1/guardian/devices/$deviceId/policy';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerSchedulesModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  ScheduleBloc build() {
    return ScheduleBloc(
      editor: createPolicySectionEditor(deps.di, const ScheduleSection()),
      newId: () => 'p-novo',
    );
  }

  TypeMatcher<PolicySectionEditing<ScheduleRules>> editing() {
    return isA<PolicySectionEditing<ScheduleRules>>();
  }

  Future<void> start(ScheduleBloc bloc) async {
    bloc.add(const ScheduleStarted(deviceId));
    await bloc.stream.firstWhere(
      (ScheduleState state) => state is PolicySectionEditing<ScheduleRules>,
    );
  }

  List<String> ids(PolicySectionEditing<ScheduleRules> state) {
    return state.draft.blockPeriods.map((BlockPeriod period) => period.id).toList();
  }

  test('o modulo registra o BLoC de horarios', () {
    final ScheduleBloc bloc = deps.di<ScheduleBloc>();
    addTearDown(bloc.close);
    expect(bloc.state, isA<PolicySectionLoading<ScheduleRules>>());
  });

  blocTest<ScheduleBloc, ScheduleState>(
    'carrega horarios e periodos da politica',
    build: build,
    act: start,
    skip: 1,
    expect: () => <Matcher>[
      editing()
          .having(
            (PolicySectionEditing<ScheduleRules> s) => s.draft.allowedHours.enabled,
            'horarios',
            isFalse,
          )
          .having(ids, 'periodos', <String>['p1']),
    ],
  );

  blocTest<ScheduleBloc, ScheduleState>(
    'horarios permitidos: ligar, acrescentar, remover e copiar para todos os dias',
    build: build,
    act: (ScheduleBloc bloc) async {
      await start(bloc);
      const DayWindow sunday = DayWindow(LocalTime(10, 0), LocalTime(18, 0));
      bloc
        ..add(const AllowedHoursToggled(true))
        ..add(const AllowedHoursWindowAdded(weekday: 7, window: sunday))
        ..add(const AllowedHoursWindowRemoved(weekday: 1, window: sunday))
        ..add(const AllowedHoursDayCopiedToAll(7));
    },
    skip: 2,
    expect: () => <Matcher>[
      editing().having(
        (PolicySectionEditing<ScheduleRules> s) => s.draft.allowedHours.windows.single.days,
        'janela padrao',
        <int>[1, 2, 3, 4, 5, 6, 7],
      ),
      editing().having(
        (PolicySectionEditing<ScheduleRules> s) => s.draft.allowedHours.windows,
        'domingo com duas janelas',
        hasLength(2),
      ),
      // Remover uma janela que nao existe no dia nao muda o rascunho: nada e emitido.
      editing().having(
        (PolicySectionEditing<ScheduleRules> s) => s.draft.allowedHours.windows,
        'todos os dias iguais ao domingo',
        hasLength(2),
      ),
    ],
    verify: (ScheduleBloc bloc) {
      final PolicySectionEditing<ScheduleRules> state =
          bloc.state as PolicySectionEditing<ScheduleRules>;
      for (final TimeWindow window in state.draft.allowedHours.windows) {
        expect(window.days, <int>[1, 2, 3, 4, 5, 6, 7]);
      }
    },
  );

  blocTest<ScheduleBloc, ScheduleState>(
    'periodos: sugestao, gravar, desligar e apagar',
    build: build,
    act: (ScheduleBloc bloc) async {
      await start(bloc);
      final DateTime now = DateTime(2026, 11, 17, 15, 30);
      bloc
        ..add(const BlockPeriodSuggestionAdded(BlockPeriodSuggestion.school))
        ..add(
          BlockPeriodSaved(
            BlockPeriodDraft(
              id: 'p1',
              label: 'Dormir',
              kind: BlockPeriodKind.weekly,
              days: const <int>{1, 2, 3, 4, 5},
              start: const LocalTime(22, 0),
              end: const LocalTime(6, 0),
              startAt: now,
              endAt: now,
            ),
          ),
        )
        ..add(
          BlockPeriodSaved(
            BlockPeriodDraft(
              label: '',
              kind: BlockPeriodKind.weekly,
              days: const <int>{1},
              start: const LocalTime(8, 0),
              end: const LocalTime(9, 0),
              startAt: now,
              endAt: now,
            ),
          ),
        )
        ..add(const BlockPeriodToggled(periodId: 'p-novo', enabled: false))
        ..add(const BlockPeriodDeleted('p1'));
    },
    skip: 2,
    expect: () => <Matcher>[
      editing().having(ids, 'sugestao com id gerado', <String>['p1', 'p-novo']),
      editing().having(
        (PolicySectionEditing<ScheduleRules> s) => s.draft.blockPeriods.first.label,
        'periodo editado',
        'Dormir',
      ),
      // O rascunho com problema nao e gravado.
      editing().having(
        (PolicySectionEditing<ScheduleRules> s) => s.draft.blockPeriods.last.enabled,
        'desligado',
        isFalse,
      ),
      editing().having(ids, 'apagado', <String>['p-novo']),
    ],
  );

  blocTest<ScheduleBloc, ScheduleState>(
    'salvar envia horarios e periodos juntos',
    setUp: () {
      deps.backend.onJson('PUT', policyPath, <String, Object?>{
        'policyVersion': 13,
        'policy': policyJson()..['blockPeriods'] = <Object?>[],
      });
    },
    build: build,
    act: (ScheduleBloc bloc) async {
      await start(bloc);
      bloc
        ..add(const BlockPeriodDeleted('p1'))
        ..add(const ScheduleSaveRequested());
      await bloc.stream.firstWhere(
        (ScheduleState state) =>
            state is PolicySectionEditing<ScheduleRules> && state.status == SectionSaveStatus.saved,
      );
    },
    verify: (_) {
      final Map<String, Object?> body = deps.backend.lastBody('PUT', policyPath);
      expect(body['baseVersion'], 12);
      final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
      expect(sent['blockPeriods'], isEmpty);
      expect(sent['allowedHours'], isNotNull);
    },
  );
}
