import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/domain/entities/policy_section.dart';
import 'schedule_rules.dart';

/// Secao "horarios" da politica: horarios permitidos e periodos de bloqueio.
final class ScheduleSection implements PolicySection<ScheduleRules> {
  const ScheduleSection();

  @override
  ScheduleRules read(Policy policy) {
    return ScheduleRules(allowedHours: policy.allowedHours, blockPeriods: policy.blockPeriods);
  }

  @override
  Policy write(Policy policy, ScheduleRules value) {
    return policy.copyWith(allowedHours: value.allowedHours, blockPeriods: value.blockPeriods);
  }
}
