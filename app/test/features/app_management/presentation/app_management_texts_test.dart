import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/app_management/presentation/texts/app_management_texts.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';

void main() {
  group('resumos', () {
    test('apps e excecoes', () {
      const AppsPolicy apps = AppsPolicy(
        rules: <String, AppRule>{
          'a': AppRule(state: AppRuleState.blocked),
          'b': AppRule(state: AppRuleState.exception),
          'c': AppRule(state: AppRuleState.allowed, dailyLimitMinutes: 30),
        },
      );
      expect(appsSummary(apps), '1 bloqueado, 1 exceção, 1 com limite próprio');
      expect(appsSummary(const AppsPolicy()), 'Nenhuma regra por app');
      expect(exceptionsSummary(apps), 'Emergência, sistema e 1 app liberado');
    });
  });
}
