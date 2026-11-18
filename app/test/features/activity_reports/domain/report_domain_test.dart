import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/day_timeline.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/event_group.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/report_period.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/usage_session.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_entry.dart';

void main() {
  group('ReportPeriod', () {
    const String today = '2026-11-17';

    test('atalhos partem do dia da cota do aparelho', () {
      expect(ReportPeriod.preset(ReportPreset.today, today: today).from, today);
      final ReportPeriod yesterday = ReportPeriod.preset(ReportPreset.yesterday, today: today);
      expect(yesterday.from, '2026-11-16');
      expect(yesterday.isSingleDay, isTrue);
      final ReportPeriod week = ReportPeriod.preset(ReportPreset.last7, today: today);
      expect(week.from, '2026-11-11');
      expect(week.days, 7);
      final ReportPeriod month = ReportPeriod.preset(ReportPreset.last30, today: today);
      expect(month.from, '2026-10-19');
      expect(month.days, 30);
    });

    test('personalizado ordena, nao passa de hoje e respeita o maximo de dias', () {
      final ReportPeriod swapped = ReportPeriod.custom('2026-11-10', '2026-11-01', today: today);
      expect(swapped.from, '2026-11-01');
      expect(swapped.to, '2026-11-10');
      final ReportPeriod future = ReportPeriod.custom('2026-11-15', '2026-12-01', today: today);
      expect(future.to, today);
      final ReportPeriod long = ReportPeriod.custom('2026-01-01', today, today: today);
      expect(long.days, ReportPeriod.maxDays);
      expect(long.to, today);
    });

    test('escolha personalizada incompleta cai no atalho', () {
      const ReportSelection incomplete = ReportSelection(preset: ReportPreset.custom);
      expect(incomplete.periodFor(today), ReportPeriod.preset(ReportPreset.custom, today: today));
      const ReportSelection custom = ReportSelection(
        preset: ReportPreset.custom,
        customFrom: '2026-11-01',
        customTo: '2026-11-03',
      );
      expect(custom.periodFor(today).days, 3);
    });

    test('sem dia da cota informado usa a data local', () {
      expect(quotaDayOf('', DateTime(2026, 11, 17, 23, 59)), '2026-11-17');
      expect(quotaDayOf('2026-11-16', DateTime(2026, 11, 17)), '2026-11-16');
    });
  });

  group('linha do tempo', () {
    UsageSession session(int startMin, int endMin) {
      return UsageSession(
        package: 'com.a',
        label: 'A',
        category: AppCategory.games,
        start: startMin * 60000,
        end: endMin * 60000,
        durationMs: (endMin - startMin) * 60000,
        tzOffsetMin: -180,
      );
    }

    test('ordena as sessoes e marca as pausas longas', () {
      final DayTimeline timeline = DayTimeline.fromSessions(<UsageSession>[
        session(100, 130),
        session(0, 20),
        session(25, 40),
      ]);
      final List<TimelineItem> items = timeline.items;
      expect(items.whereType<TimelineSession>(), hasLength(3));
      final List<TimelineGap> gaps = items.whereType<TimelineGap>().toList();
      expect(gaps, hasLength(1));
      expect(gaps.single.gap.durationMs, 60 * 60000);
      expect(items[2], isA<TimelineGap>());
      expect(timeline.longestGapMs, 60 * 60000);
      expect(timeline.totalMs, 65 * 60000);
    });

    test('horario local usa o deslocamento de fuso da sessao', () {
      final UsageSession item = session(600, 630);
      expect(item.localStart.hour, 7);
      expect(item.localStart.minute, 0);
    });

    test('dia sem sessoes fica vazio', () {
      expect(DayTimeline.fromSessions(const <UsageSession>[]).isEmpty, isTrue);
    });
  });

  test('grupos de filtro dos eventos', () {
    expect(EventGroup.of('blocked_attempt'), EventGroup.blocks);
    expect(EventGroup.of('clock_changed'), EventGroup.security);
    expect(EventGroup.of('tipo_novo'), EventGroup.system);
    expect(EventGroup.all.types, isEmpty);
  });
}
