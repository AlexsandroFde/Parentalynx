import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/day_timeline.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/report_period.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/report_summary.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/usage_session.dart';
import 'package:parentalynx/features/activity_reports/domain/usecases/get_day_timeline.dart';
import 'package:parentalynx/features/activity_reports/domain/usecases/get_report_summary.dart';
import 'package:parentalynx/features/activity_reports/presentation/bloc/activity_reports/activity_reports_bloc.dart';
import 'package:parentalynx/features/activity_reports/presentation/bloc/day_timeline/day_timeline_bloc.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_entry.dart';

import '../../../support/fakes.dart';

class _MockGetReportSummary extends Mock implements GetReportSummary {}

class _MockGetDayTimeline extends Mock implements GetDayTimeline {}

ReportSummary _summary(String from, String to, {int totalMs = 60000}) {
  return ReportSummary(
    from: from,
    to: to,
    timezone: 'America/Fortaleza',
    totals: ReportTotals(
      totalMs: totalMs,
      quotaMs: totalMs,
      daysWithUse: 1,
      avgPerDayMs: totalMs,
      blockedAttempts: 0,
      sessions: 1,
      opens: 1,
    ),
    daily: const <DailyUsage>[],
    apps: const <AppUsage>[],
    categories: const <CategoryUsage>[],
    hourly: List<int>.filled(24, 0),
    blockedByApp: const <BlockedApp>[],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(ReportPeriod.preset(ReportPreset.last7, today: '2026-11-17'));
  });

  group('ActivityReportsBloc', () {
    late _MockGetReportSummary getSummary;
    final ReportSummary week = _summary('2026-11-11', '2026-11-17');
    final ReportSummary today = _summary('2026-11-17', '2026-11-17');
    const ReportQuery weekQuery = ReportQuery(
      deviceId: 'dev-1',
      today: '2026-11-17',
      selection: ReportSelection.initial,
    );
    const ReportQuery todayQuery = ReportQuery(
      deviceId: 'dev-1',
      today: '2026-11-17',
      selection: ReportSelection(preset: ReportPreset.today),
    );

    setUp(() {
      getSummary = _MockGetReportSummary();
      when(() => getSummary(any(), any())).thenAnswer((Invocation call) async {
        final ReportPeriod period = call.positionalArguments[1] as ReportPeriod;
        return Ok<ReportSummary>(period.isSingleDay ? today : week);
      });
    });

    ActivityReportsBloc build() {
      return ActivityReportsBloc(getReportSummary: getSummary, clock: FakeClock());
    }

    blocTest<ActivityReportsBloc, ActivityReportsState>(
      'o aparelho em foco carrega os ultimos 7 dias',
      build: build,
      act: (ActivityReportsBloc bloc) {
        bloc.add(const ReportsDeviceChanged(deviceId: 'dev-1', deviceToday: '2026-11-17'));
      },
      expect: () => <ActivityReportsState>[
        const ReportsLoading(weekQuery),
        ReportsLoaded(weekQuery, week),
      ],
      verify: (_) {
        final ReportPeriod period =
            verify(() => getSummary('dev-1', captureAny())).captured.single as ReportPeriod;
        expect(period.from, '2026-11-11');
        expect(period.to, '2026-11-17');
      },
    );

    blocTest<ActivityReportsBloc, ActivityReportsState>(
      'trocar o periodo mantem o relatorio anterior enquanto o novo carrega',
      build: build,
      seed: () => ReportsLoaded(weekQuery, week),
      act: (ActivityReportsBloc bloc) => bloc.add(const ReportsPresetSelected(ReportPreset.today)),
      expect: () => <ActivityReportsState>[
        ReportsUpdating(todayQuery, week),
        ReportsLoaded(todayQuery, today),
      ],
    );

    blocTest<ActivityReportsBloc, ActivityReportsState>(
      'falha sem relatorio anterior vira erro e com relatorio anterior mantem o antigo',
      setUp: () {
        when(() => getSummary(any(), any()))
            .thenAnswer((_) async => const Err<ReportSummary>(NetworkFailure()));
      },
      build: build,
      seed: () => ReportsLoaded(weekQuery, week),
      act: (ActivityReportsBloc bloc) => bloc.add(const ReportsPresetSelected(ReportPreset.today)),
      expect: () => <ActivityReportsState>[
        ReportsUpdating(todayQuery, week),
        ReportsStale(todayQuery, week, const NetworkFailure()),
      ],
    );

    blocTest<ActivityReportsBloc, ActivityReportsState>(
      'primeira consulta com falha mostra o erro',
      setUp: () {
        when(() => getSummary(any(), any()))
            .thenAnswer((_) async => const Err<ReportSummary>(NetworkFailure()));
      },
      build: build,
      act: (ActivityReportsBloc bloc) {
        bloc.add(const ReportsDeviceChanged(deviceId: 'dev-1', deviceToday: '2026-11-17'));
      },
      expect: () => <ActivityReportsState>[
        const ReportsLoading(weekQuery),
        const ReportsError(weekQuery, NetworkFailure()),
      ],
    );

    blocTest<ActivityReportsBloc, ActivityReportsState>(
      'escolher periodo antes de haver aparelho nao consulta nada',
      build: build,
      act: (ActivityReportsBloc bloc) => bloc.add(const ReportsPresetSelected(ReportPreset.today)),
      expect: () => <ActivityReportsState>[],
      verify: (_) => verifyNever(() => getSummary(any(), any())),
    );

    test('recarregar conclui o aviso de fim quando o relatorio chega', () async {
      final ActivityReportsBloc bloc = build()
        ..add(const ReportsDeviceChanged(deviceId: 'dev-1', deviceToday: '2026-11-17'));
      addTearDown(bloc.close);
      await expectLater(bloc.stream, emitsThrough(isA<ReportsLoaded>()));

      final Completer<void> done = Completer<void>();
      bloc.add(ReportsRefreshRequested(completer: done));

      await expectLater(done.future, completes);
      expect(bloc.state, ReportsLoaded(weekQuery, week));
    });
  });

  group('DayTimelineBloc', () {
    late _MockGetDayTimeline getTimeline;
    final DayTimeline timeline = DayTimeline.fromSessions(const <UsageSession>[
      UsageSession(
        package: 'com.a',
        label: 'A',
        category: AppCategory.games,
        start: 0,
        end: 60000,
        durationMs: 60000,
        tzOffsetMin: 0,
      ),
    ]);

    setUp(() {
      getTimeline = _MockGetDayTimeline();
      when(() => getTimeline(any(), day: any(named: 'day')))
          .thenAnswer((_) async => Ok<DayTimeline>(timeline));
    });

    DayTimelineBloc build() => DayTimelineBloc(getDayTimeline: getTimeline, clock: FakeClock());

    blocTest<DayTimelineBloc, DayTimelineState>(
      'abre no dia pedido e navega para o dia anterior',
      build: build,
      act: (DayTimelineBloc bloc) => bloc
        ..add(
          const DayTimelineStarted(
            deviceId: 'dev-1',
            deviceToday: '2026-11-17',
            initialDay: '2026-11-16',
          ),
        )
        ..add(const DayTimelinePreviousDayRequested()),
      expect: () => <DayTimelineState>[
        const DayTimelineLoading(day: '2026-11-16', today: '2026-11-17'),
        DayTimelineLoaded(day: '2026-11-16', today: '2026-11-17', timeline: timeline),
        const DayTimelineLoading(day: '2026-11-15', today: '2026-11-17'),
        DayTimelineLoaded(day: '2026-11-15', today: '2026-11-17', timeline: timeline),
      ],
    );

    blocTest<DayTimelineBloc, DayTimelineState>(
      'nao passa do dia corrente e mostra o dia vazio',
      setUp: () {
        when(() => getTimeline(any(), day: any(named: 'day'))).thenAnswer(
          (_) async => Ok<DayTimeline>(DayTimeline.fromSessions(const <UsageSession>[])),
        );
      },
      build: build,
      act: (DayTimelineBloc bloc) => bloc
        ..add(const DayTimelineStarted(deviceId: 'dev-1', deviceToday: '2026-11-17'))
        ..add(const DayTimelineNextDayRequested()),
      expect: () => <DayTimelineState>[
        const DayTimelineLoading(day: '2026-11-17', today: '2026-11-17'),
        const DayTimelineEmpty(day: '2026-11-17', today: '2026-11-17'),
      ],
    );
  });
}
