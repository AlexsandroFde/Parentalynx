import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';

/// Regras das entidades da politica, sem JSON.
void main() {
  const Policy policy = Policy(
    timezone: 'America/Fortaleza',
    dailyLimit: DailyLimit(enabled: true, minutes: 150, perWeekday: <int, int>{6: 240, 7: 240}),
    overrides: PolicyOverrides(
      extraTime: <ExtraTimeGrant>[
        ExtraTimeGrant(id: 'e1', day: '2026-11-17', minutes: 30, grantedAt: 1),
        ExtraTimeGrant(id: 'e2', day: '2026-11-17', minutes: 15, grantedAt: 2),
        ExtraTimeGrant(id: 'e3', day: '2026-11-16', minutes: 60, grantedAt: 3),
      ],
      manualLock: ManualLock(active: true, until: 2000, setAt: 1000),
      suspension: Suspension(
        until: 5000,
        scopes: <SuspensionScope>[SuspensionScope.dailyLimit, SuspensionScope.schedules],
      ),
    ),
  );

  group('Policy', () {
    test('limite efetivo soma o tempo extra do dia e respeita o dia da semana', () {
      // 17/11/2026 e terca: 150 min mais 45 extras.
      expect(policy.effectiveLimitMinutes('2026-11-17'), 195);
      // 21/11/2026 e sabado: 240 min, sem extra.
      expect(policy.effectiveLimitMinutes('2026-11-21'), 240);
      expect(policy.overrides.extraMinutesFor('2026-11-16'), 60);
    });

    test('limite desligado devolve nulo', () {
      final Policy off = policy.copyWith(dailyLimit: policy.dailyLimit.copyWith(enabled: false));
      expect(off.effectiveLimitMinutes('2026-11-17'), isNull);
    });

    test('bloqueio manual e suspensao dependem do instante', () {
      expect(policy.overrides.manualLock.isActiveAt(1500), isTrue);
      expect(policy.overrides.manualLock.isActiveAt(2500), isFalse);
      expect(const ManualLock(active: true).isActiveAt(999999), isTrue);
      expect(policy.overrides.suspension.isActiveAt(4000), isTrue);
      expect(policy.overrides.suspension.isActiveAt(5000), isFalse);
      expect(Suspension.none.isActiveAt(0), isFalse);
    });

    test('regras editaveis ignoram os comandos temporarios', () {
      final Policy other = policy.copyWith(overrides: const PolicyOverrides());
      expect(other.sameRulesAs(policy), isTrue);
      expect(other == policy, isFalse);
      final Policy changed = policy.copyWith(dailyLimit: policy.dailyLimit.copyWith(minutes: 60));
      expect(changed.sameRulesAs(policy), isFalse);
    });
  });

  group('DailyLimit', () {
    test('ligar o limite por dia comeca cada dia com o valor que vale hoje', () {
      const DailyLimit limit = DailyLimit(
        enabled: true,
        minutes: 120,
        perWeekday: <int, int>{6: 240},
      );
      final DailyLimit perDay = limit.withPerWeekday(true);
      expect(perDay.perWeekday, <int, int>{1: 120, 2: 120, 3: 120, 4: 120, 5: 120, 6: 240, 7: 120});
      expect(perDay.withPerWeekday(false).sameEveryDay, isTrue);
      expect(perDay.withDayMinutes(1, 30).minutesFor(1), 30);
    });
  });

  group('AppsPolicy', () {
    test('regra padrao nao e gravada', () {
      const AppsPolicy apps = AppsPolicy();
      final AppsPolicy blocked = apps.withRule(
        'com.jogo',
        const AppRule(state: AppRuleState.blocked),
      );
      expect(blocked.rules.keys, <String>['com.jogo']);
      expect(blocked.blockedCount, 1);
      final AppsPolicy back = blocked.withRule('com.jogo', AppRule.defaultAllowed);
      expect(back.rules, isEmpty);
    });

    test('trocar o estado limpa o que nao se aplica', () {
      const AppRule exception = AppRule(
        state: AppRuleState.exception,
        countsTowardLimit: true,
        dailyLimitMinutes: 30,
      );
      final AppRule allowed = exception.withState(AppRuleState.allowed);
      expect(allowed.countsTowardLimit, isFalse);
      expect(allowed.dailyLimitMinutes, 30);
      final AppRule blocked = exception.withState(AppRuleState.blocked);
      expect(blocked.dailyLimitMinutes, isNull);
    });
  });

  group('LocalTime', () {
    test('le, formata e compara', () {
      expect(LocalTime.parse('07:05').toString(), '07:05');
      expect(LocalTime.parse('24:00'), LocalTime.endOfDay);
      expect(LocalTime.fromMinutes(1290).toString(), '21:30');
      expect(const LocalTime(21, 0).compareTo(const LocalTime(7, 0)), greaterThan(0));
    });

    test('recusa horario invalido', () {
      for (final String bad in <String>['7', '25:00', '24:30', '12:60', 'ab:cd', '-1:00']) {
        expect(() => LocalTime.parse(bad), throwsA(isA<FormatException>()), reason: bad);
      }
    });
  });

  group('WebPolicy.normalizeDomain', () {
    test('limpa esquema, caminho, porta e www', () {
      expect(WebPolicy.normalizeDomain('https://www.Exemplo.com/pagina?x=1'), 'exemplo.com');
      expect(WebPolicy.normalizeDomain('sub.exemplo.com.br:8080'), 'sub.exemplo.com.br');
      expect(WebPolicy.normalizeDomain('  exemplo.com  '), 'exemplo.com');
    });

    test('recusa o que nao e dominio', () {
      expect(WebPolicy.normalizeDomain('nao e dominio'), isNull);
      expect(WebPolicy.normalizeDomain('localhost'), isNull);
      expect(WebPolicy.normalizeDomain(''), isNull);
    });
  });
}
