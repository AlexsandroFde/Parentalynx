import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy_section.dart';

/// Secao do limite diario, so para os testes do nucleo da politica.
class TestLimitSection implements PolicySection<DailyLimit> {
  const TestLimitSection();

  @override
  DailyLimit read(Policy policy) => policy.dailyLimit;

  @override
  Policy write(Policy policy, DailyLimit value) => policy.copyWith(dailyLimit: value);
}

/// Secao das protecoes, para provar que secoes diferentes nao entram em conflito.
class TestProtectionSection implements PolicySection<ProtectionPolicy> {
  const TestProtectionSection();

  @override
  ProtectionPolicy read(Policy policy) => policy.protection;

  @override
  Policy write(Policy policy, ProtectionPolicy value) => policy.copyWith(protection: value);
}
