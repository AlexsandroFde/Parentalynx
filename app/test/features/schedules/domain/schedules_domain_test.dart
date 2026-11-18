import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/schedules/domain/entities/block_period_draft.dart';
import 'package:parentalynx/features/schedules/domain/entities/block_period_suggestion.dart';
import 'package:parentalynx/features/schedules/domain/entities/day_window.dart';
import 'package:parentalynx/features/schedules/domain/services/allowed_hours_editing.dart';
import 'package:parentalynx/features/schedules/domain/services/block_period_editing.dart';
import 'package:parentalynx/features/schedules/domain/services/period_ids.dart';

void main() {
  group('horarios permitidos', () {
    const AllowedHours hours = AllowedHours(
      enabled: true,
      windows: <TimeWindow>[
        TimeWindow(days: <int>[1, 2, 3, 4, 5], start: LocalTime(7, 0), end: LocalTime(20, 30)),
        TimeWindow(days: <int>[6], start: LocalTime(9, 0), end: LocalTime(12, 0)),
        TimeWindow(days: <int>[6], start: LocalTime(14, 0), end: LocalTime(22, 0)),
      ],
    );

    test('abre por dia e identifica os dias bloqueados', () {
      final WeekWindows week = expandAllowedHours(hours);
      expect(week[1], <DayWindow>[const DayWindow(LocalTime(7, 0), LocalTime(20, 30))]);
      expect(week[6], hasLength(2));
      expect(week[7], isEmpty);
      expect(blockedDays(week), <int>[7]);
    });

    test('ida e volta junta janelas iguais de dias diferentes', () {
      final List<TimeWindow> compact = compactAllowedHours(expandAllowedHours(hours));
      expect(compact, hasLength(3));
      expect(compact.first.days, <int>[1, 2, 3, 4, 5]);
      expect(expandAllowedHours(AllowedHours(enabled: true, windows: compact))[6], hasLength(2));
    });

    test('adicionar, remover e copiar', () {
      WeekWindows week = expandAllowedHours(hours);
      const DayWindow sunday = DayWindow(LocalTime(10, 0), LocalTime(18, 0));
      week = addDayWindow(week, 7, sunday);
      week = addDayWindow(week, 7, sunday);
      expect(week[7], <DayWindow>[sunday]);
      week = removeDayWindow(week, 7, sunday);
      expect(week[7], isEmpty);
      week = copyDayWindows(week, from: 1, to: const <int>[6, 7]);
      expect(week[7], week[1]);
      expect(blockedDays(week), isEmpty);
    });

    test('janela precisa terminar depois de comecar', () {
      expect(validateDayWindow(const LocalTime(8, 0), const LocalTime(8, 0)), isNotNull);
      expect(validateDayWindow(const LocalTime(21, 0), const LocalTime(7, 0)), isNotNull);
      expect(validateDayWindow(const LocalTime(8, 0), LocalTime.endOfDay), isNull);
    });

    test('janela nova nao pode cobrir horario ja liberado no dia', () {
      const List<DayWindow> day = <DayWindow>[DayWindow(LocalTime(7, 0), LocalTime(12, 0))];
      expect(
        validateNewDayWindow(day, const DayWindow(LocalTime(11, 0), LocalTime(14, 0))),
        'Esse horário se sobrepõe a 07:00 às 12:00. Ajuste o início ou o fim.',
      );
      expect(
        validateNewDayWindow(day, const DayWindow(LocalTime(7, 0), LocalTime(12, 0))),
        'Esse horário já está liberado neste dia.',
      );
      expect(
        validateNewDayWindow(day, const DayWindow(LocalTime(14, 0), LocalTime(12, 0))),
        isNotNull,
      );
      // Encostar no fim de outra janela nao e sobrepor.
      expect(
        validateNewDayWindow(day, const DayWindow(LocalTime(12, 0), LocalTime(14, 0))),
        isNull,
      );
    });

    test('ligar sem janelas comeca com um horario comum todos os dias', () {
      final AllowedHours enabled = withAllowedHoursEnabled(AllowedHours.disabled, true);
      expect(enabled.enabled, isTrue);
      expect(enabled.windows, <TimeWindow>[defaultAllowedWindow]);
      expect(withAllowedHoursEnabled(hours, false).windows, hours.windows);
    });
  });

  group('periodos de bloqueio', () {
    final DateTime now = DateTime(2026, 11, 17, 15, 30);

    BlockPeriodDraft draft({
      String label = 'Hora de dormir',
      BlockPeriodKind kind = BlockPeriodKind.weekly,
      Set<int> days = const <int>{5, 1},
      LocalTime end = const LocalTime(7, 0),
      DateTime? endAt,
    }) {
      return BlockPeriodDraft(
        label: label,
        kind: kind,
        days: days,
        start: const LocalTime(21, 0),
        end: end,
        startAt: now,
        endAt: endAt ?? now.add(const Duration(hours: 2)),
      );
    }

    test('rascunho explica o que falta antes de virar regra', () {
      expect(draft(label: '  ').problem, contains('Dê um nome'));
      expect(draft(days: const <int>{}).problem, 'Escolha pelo menos um dia da semana.');
      expect(draft(end: const LocalTime(21, 0)).problem, 'O início e o fim não podem ser iguais.');
      expect(
        draft(kind: BlockPeriodKind.once, endAt: now).problem,
        'O fim precisa ser depois do início.',
      );
      expect(draft().problem, isNull);
      expect(
        draft(
          kind: BlockPeriodKind.once,
          endAt: now.add(const Duration(hours: 1)),
        ).problemAt(now.add(const Duration(hours: 2))),
        'Esse período já terminou. Escolha um fim depois de agora.',
      );
      expect(draft().problemAt(now.add(const Duration(days: 30))), isNull);

      final BlockPeriod period = draft(label: ' Hora de dormir ').toPeriod('p9');
      expect(period.id, 'p9');
      expect(period.label, 'Hora de dormir');
      expect(period.days, <int>[1, 5]);
    });

    test('gravar troca o periodo de mesmo id ou acrescenta no fim', () {
      final BlockPeriod bedtime = BlockPeriodSuggestion.bedtime.toPeriod('p1');
      final BlockPeriod school = BlockPeriodSuggestion.school.toPeriod('p2');
      List<BlockPeriod> periods = BlockPeriodEditing.upsert(const <BlockPeriod>[], bedtime);
      periods = BlockPeriodEditing.upsert(periods, school);
      expect(periods.map((BlockPeriod period) => period.id), <String>['p1', 'p2']);

      periods = BlockPeriodEditing.setEnabled(periods, 'p1', false);
      expect(periods.first.enabled, isFalse);
      periods = BlockPeriodEditing.upsert(periods, bedtime);
      expect(periods.first.enabled, isTrue);
      expect(periods, hasLength(2));

      expect(BlockPeriodEditing.remove(periods, 'p1').single.id, 'p2');
    });

    test('lista cheia nao aceita periodo novo', () {
      final List<BlockPeriod> full = <BlockPeriod>[
        for (int i = 0; i < BlockPeriodEditing.maxPeriods; i++)
          BlockPeriodSuggestion.school.toPeriod('p$i'),
      ];
      expect(BlockPeriodEditing.canAdd(full), isFalse);
      expect(
        BlockPeriodEditing.upsert(full, BlockPeriodSuggestion.bedtime.toPeriod('novo')),
        same(full),
      );
    });

    test('periodo pontual terminado e inicio sugerido na proxima hora cheia', () {
      final BlockPeriod once = draft(
        kind: BlockPeriodKind.once,
        endAt: now.add(const Duration(hours: 1)),
      ).toPeriod('p3');
      expect(BlockPeriodEditing.hasEnded(once, now.millisecondsSinceEpoch), isFalse);
      expect(
        BlockPeriodEditing.hasEnded(once, now.add(const Duration(hours: 2)).millisecondsSinceEpoch),
        isTrue,
      );
      expect(BlockPeriodEditing.suggestedInstant(now), DateTime(2026, 11, 17, 16));
      expect(BlockPeriodEditing.suggestedInstant(now, hoursAhead: 1), DateTime(2026, 11, 17, 17));
    });
  });

  test('identificador gerado tem o formato UUID versao 4', () {
    final RegExp pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(pattern.hasMatch(newUuid()), isTrue);
    expect(newUuid(), isNot(newUuid()));
    expect(newUuid(Random(7)), newUuid(Random(7)));
  });
}
