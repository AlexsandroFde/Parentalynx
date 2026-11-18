import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/domain/entities/policy_section.dart';

/// Secao "protecao" da politica: bloqueio por adulteracao e travas do sistema.
final class ProtectionSection implements PolicySection<ProtectionPolicy> {
  const ProtectionSection();

  @override
  ProtectionPolicy read(Policy policy) => policy.protection;

  @override
  Policy write(Policy policy, ProtectionPolicy value) => policy.copyWith(protection: value);
}
