import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/domain/entities/policy_section.dart';

/// Secao "aplicativos" da politica: padrao para apps novos e regras por app.
final class AppsSection implements PolicySection<AppsPolicy> {
  const AppsSection();

  @override
  AppsPolicy read(Policy policy) => policy.apps;

  @override
  Policy write(Policy policy, AppsPolicy value) => policy.copyWith(apps: value);
}
