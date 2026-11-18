import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/domain/entities/policy_section.dart';

/// Secao "limite diario" da politica, editada pela tela de limite diario.
final class DailyLimitSection implements PolicySection<DailyLimit> {
  const DailyLimitSection();

  @override
  DailyLimit read(Policy policy) => policy.dailyLimit;

  @override
  Policy write(Policy policy, DailyLimit value) => policy.copyWith(dailyLimit: value);
}
