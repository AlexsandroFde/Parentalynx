import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/screen_time/domain/services/daily_limit_editing.dart';

void main() {
  group('avisos de pouco tempo', () {
    const DailyLimit limit = DailyLimit(enabled: true, minutes: 150, warnAtMinutes: <int>[5, 15]);

    test('ligar mantem a lista sem repeticao, do maior para o menor', () {
      expect(limit.withWarning(30, enabled: true).warnAtMinutes, <int>[30, 15, 5]);
      expect(limit.withWarning(15, enabled: true).warnAtMinutes, <int>[15, 5]);
      expect(limit.withWarning(5, enabled: false).warnAtMinutes, <int>[15]);
    });

    test('no maximo quatro avisos ligados', () {
      final DailyLimit full = limit.withWarning(30, enabled: true).withWarning(10, enabled: true);
      expect(full.warnAtMinutes, hasLength(DailyLimitWarnings.maxWarnings));
      expect(full.canEnableWarning(1), isFalse);
      expect(full.canEnableWarning(10), isTrue);
      expect(full.withWarning(1, enabled: true), full);
      expect(DailyLimitWarnings.options, <int>[30, 15, 10, 5, 1]);
    });
  });
}
