import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/schedules/presentation/texts/schedule_texts.dart';

void main() {
  group('resumos', () {
    test('horarios e periodos', () {
      expect(allowedHoursSummary(AllowedHours.disabled), 'Sem restrição de horário');
      expect(
        allowedHoursSummary(
          const AllowedHours(
            enabled: true,
            windows: <TimeWindow>[
              TimeWindow(
                days: <int>[1, 2, 3, 4, 5, 6, 7],
                start: LocalTime(7, 0),
                end: LocalTime(21, 0),
              ),
            ],
          ),
        ),
        'Todos os dias, 07:00 às 21:00',
      );
      const BlockPeriod bedtime = BlockPeriod.weekly(
        id: 'p1',
        label: 'Hora de dormir',
        days: <int>[1, 2, 3, 4, 5, 6, 7],
        start: LocalTime(21, 0),
        end: LocalTime(7, 0),
      );
      expect(describeBlockPeriod(bedtime), 'Todos os dias, 21:00 às 07:00 do dia seguinte');
      expect(blockPeriodsSummary(const <BlockPeriod>[]), 'Nenhum período');
      expect(blockPeriodsSummary(const <BlockPeriod>[bedtime]), '1 ativo: Hora de dormir');
      expect(
        blockPeriodsSummary(<BlockPeriod>[bedtime.withEnabled(false)]),
        '1 período desativado',
      );
    });
  });
}
