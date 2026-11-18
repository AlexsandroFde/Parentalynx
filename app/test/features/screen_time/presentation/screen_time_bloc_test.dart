import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/presentation/editing/policy_section_state.dart';
import 'package:parentalynx/features/screen_time/presentation/bloc/screen_time/screen_time_bloc.dart';
import 'package:parentalynx/features/screen_time/screen_time_module.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart';
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

  TypeMatcher<PolicySectionEditing<DailyLimit>> editing() {
    return isA<PolicySectionEditing<DailyLimit>>();
  }

  Future<void> start(ScreenTimeBloc bloc) async {
    bloc.add(const ScreenTimeStarted(deviceId));
    await bloc.stream.firstWhere(
      (ScreenTimeState state) => state is PolicySectionEditing<DailyLimit>,
    );
  }

  blocTest<ScreenTimeBloc, ScreenTimeState>(
    'carrega o limite do aparelho sem alteracoes',
    build: () => deps.di<ScreenTimeBloc>(),
    act: start,
    expect: () => <Matcher>[
      isA<PolicySectionLoading<DailyLimit>>(),
      editing()
          .having((PolicySectionEditing<DailyLimit> s) => s.draft.minutes, 'minutos', 150)
          .having((PolicySectionEditing<DailyLimit> s) => s.base.version, 'versao', 12)
          .having((PolicySectionEditing<DailyLimit> s) => s.isDirty, 'alterado', isFalse),
    ],
  );

  blocTest<ScreenTimeBloc, ScreenTimeState>(
    'limite por dia da semana entra no rascunho e salvar envia a versao base',
    setUp: () {
      deps.backend.on('PUT', policyPath, (http.Request request) {
        final Map<String, Object?> body = jsonDecode(request.body) as Map<String, Object?>;
        final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
        return jsonResponse(<String, Object?>{
          'policyVersion': 13,
          'policy': <String, Object?>{...sent, 'overrides': policyJson()['overrides']},
        });
      });
    },
    build: () => deps.di<ScreenTimeBloc>(),
    act: (ScreenTimeBloc bloc) async {
      await start(bloc);
      bloc
        ..add(const DailyLimitPerWeekdayToggled(true))
        ..add(const DailyLimitWeekdayMinutesChanged(weekday: 6, minutes: 240))
        ..add(const ScreenTimeSaveRequested());
      await bloc.stream.firstWhere(
        (ScreenTimeState state) =>
            state is PolicySectionEditing<DailyLimit> && state.status == SectionSaveStatus.saved,
      );
    },
    skip: 2,
    expect: () => <Matcher>[
      editing()
          .having((PolicySectionEditing<DailyLimit> s) => s.draft.perWeekday[6], 'sabado', 150)
          .having((PolicySectionEditing<DailyLimit> s) => s.isDirty, 'alterado', isTrue),
      editing().having(
        (PolicySectionEditing<DailyLimit> s) => s.draft.minutesFor(6),
        'sabado',
        240,
      ),
      editing().having((PolicySectionEditing<DailyLimit> s) => s.isSaving, 'enviando', isTrue),
      editing()
          .having(
            (PolicySectionEditing<DailyLimit> s) => s.status,
            'status',
            SectionSaveStatus.saved,
          )
          .having((PolicySectionEditing<DailyLimit> s) => s.base.version, 'versao', 13)
          .having((PolicySectionEditing<DailyLimit> s) => s.isDirty, 'alterado', isFalse),
    ],
    verify: (_) {
      final Map<String, Object?> body = deps.backend.lastBody('PUT', policyPath);
      expect(body['baseVersion'], 12);
      final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
      expect(sent.containsKey('overrides'), isFalse);
      final Map<String, Object?> limit = sent['dailyLimit']! as Map<String, Object?>;
      expect((limit['perWeekday']! as Map<String, Object?>)['6'], 240);
    },
  );

  blocTest<ScreenTimeBloc, ScreenTimeState>(
    'avisos seguem as regras do limite e descartar volta ao que esta salvo',
    build: () => deps.di<ScreenTimeBloc>(),
    act: (ScreenTimeBloc bloc) async {
      await start(bloc);
      bloc
        ..add(const DailyLimitWarningToggled(minutes: 30, enabled: true))
        ..add(const DailyLimitEnabledChanged(false))
        ..add(const ScreenTimeDiscardRequested());
    },
    skip: 2,
    expect: () => <Matcher>[
      editing().having(
        (PolicySectionEditing<DailyLimit> s) => s.draft.warnAtMinutes,
        'avisos',
        <int>[30, 15, 5],
      ),
      editing().having((PolicySectionEditing<DailyLimit> s) => s.draft.enabled, 'ligado', isFalse),
      editing()
          .having((PolicySectionEditing<DailyLimit> s) => s.isDirty, 'alterado', isFalse)
          .having((PolicySectionEditing<DailyLimit> s) => s.draft.warnAtMinutes, 'avisos', <int>[
            15,
            5,
          ]),
    ],
  );

  blocTest<ScreenTimeBloc, ScreenTimeState>(
    'sem alteracoes salvar nao envia nada',
    build: () => deps.di<ScreenTimeBloc>(),
    act: (ScreenTimeBloc bloc) async {
      await start(bloc);
      bloc.add(const ScreenTimeSaveRequested());
    },
    skip: 2,
    expect: () => <Matcher>[],
    verify: (_) => expect(deps.backend.calls('PUT', policyPath), isEmpty),
  );
}
