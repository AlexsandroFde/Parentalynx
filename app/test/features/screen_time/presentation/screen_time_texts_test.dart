import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/screen_time/presentation/texts/screen_time_texts.dart';

void main() {
  group('resumos', () {
    test('limite diario', () {
      expect(dailyLimitSummary(DailyLimit.disabled), 'Desligado');
      expect(dailyLimitSummary(const DailyLimit(enabled: true, minutes: 150)), '2h 30min por dia');
      expect(
        dailyLimitSummary(
          const DailyLimit(enabled: true, minutes: 150, perWeekday: <int, int>{6: 240, 7: 240}),
        ),
        '2h 30min por dia (sáb e dom: 4h)',
      );
      expect(
        dailyLimitSummary(
          const DailyLimit(enabled: true, minutes: 375, perWeekday: <int, int>{1: 375}),
        ),
        '6h 15min por dia',
      );
    });
  });
}
