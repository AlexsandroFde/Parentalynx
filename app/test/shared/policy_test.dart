import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/shared/domain/policy.dart';

/// Exemplo completo do protocolo (secao 4.2).
const String _fullPolicy = '''
{
  "schema": 1,
  "timezone": "America/Fortaleza",
  "dailyLimit": {
    "enabled": true, "minutes": 150, "perWeekday": {"6": 240, "7": 240},
    "resetTime": "04:00", "warnAtMinutes": [15, 5]
  },
  "allowedHours": {
    "enabled": true,
    "windows": [{"days": [1, 2, 3, 4, 5], "start": "07:00", "end": "20:30"}]
  },
  "blockPeriods": [
    {"id": "p1", "label": "Hora de dormir", "enabled": true, "kind": "weekly",
     "days": [1, 2, 3, 4, 5, 6, 7], "start": "21:00", "end": "07:00"},
    {"id": "p2", "label": "Estudo", "enabled": false, "kind": "once",
     "startAt": 1790000000000, "endAt": 1790003600000}
  ],
  "apps": {
    "defaultForNewApps": "blocked",
    "rules": {
      "com.whatsapp": {"state": "exception", "countsTowardLimit": false},
      "com.example.jogo": {"state": "blocked"},
      "com.google.android.youtube": {"state": "allowed", "dailyLimitMinutes": 45}
    }
  },
  "web": {
    "managedBrowser": true, "logHistory": true, "safeDns": true, "safeSearch": false,
    "mode": "allowlist", "blockedDomains": ["ruim.com"], "allowedDomains": ["wikipedia.org"],
    "blockedCategories": ["adult", "gambling"]
  },
  "protection": {
    "lockOnTamper": true, "blockUninstall": true, "blockSafeBoot": true,
    "blockFactoryReset": true, "blockDateTimeChange": true, "blockAddUser": true,
    "blockUnknownSources": true, "blockUsbDebugging": false
  },
  "overrides": {
    "extraTime": [
      {"id": "e1", "day": "2026-11-17", "minutes": 30, "grantedAt": 1},
      {"id": "e2", "day": "2026-11-17", "minutes": 15, "grantedAt": 2},
      {"id": "e3", "day": "2026-11-16", "minutes": 60, "grantedAt": 3}
    ],
    "manualLock": {"active": true, "until": 2000, "setAt": 1000},
    "suspension": {"until": 5000, "scopes": ["dailyLimit", "schedules"], "setAt": 1000}
  }
}
''';

void main() {
  group('Policy', () {
    final Policy policy = Policy.fromJson(decodeJsonObject(_fullPolicy));

    test('le todas as secoes', () {
      expect(policy.timezone, 'America/Fortaleza');
      expect(policy.dailyLimit.enabled, isTrue);
      expect(policy.dailyLimit.minutes, 150);
      expect(policy.dailyLimit.resetTime, const LocalTime(4, 0));
      expect(policy.dailyLimit.minutesFor(6), 240);
      expect(policy.dailyLimit.minutesFor(2), 150);
      expect(policy.allowedHours.windowsFor(3), hasLength(1));
      expect(policy.allowedHours.windowsFor(6), isEmpty);
      expect(policy.blockPeriods, hasLength(2));
      expect(policy.blockPeriods.first.crossesMidnight, isTrue);
      expect(policy.blockPeriods.last.kind, BlockPeriodKind.once);
      expect(policy.blockPeriods.last.enabled, isFalse);
      expect(policy.apps.defaultForNewApps, NewAppDefault.blocked);
      expect(policy.apps.ruleFor('com.whatsapp').state, AppRuleState.exception);
      expect(policy.apps.ruleFor('com.google.android.youtube').dailyLimitMinutes, 45);
      expect(policy.apps.ruleFor('com.sem.regra').state, AppRuleState.allowed);
      expect(policy.apps.blockedCount, 1);
      expect(policy.apps.exceptionCount, 1);
      expect(policy.web.mode, WebMode.allowlist);
      expect(policy.web.safeSearch, isFalse);
      expect(policy.protection.lockOnTamper, isTrue);
      expect(policy.overrides.manualLock.active, isTrue);
    });

    test('ida e volta por JSON preserva tudo', () {
      final String encoded = jsonEncode(policy.toJson());
      final Policy again = Policy.fromJson(decodeJsonObject(encoded));
      expect(again, policy);
      expect(again.hashCode, policy.hashCode);
    });

    test('envio ao servidor omite os overrides', () {
      expect(policy.toJsonWith(includeOverrides: false).containsKey('overrides'), isFalse);
      expect(policy.toJson().containsKey('overrides'), isTrue);
    });

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

    test('politica minima assume os padroes', () {
      final Policy minimal = Policy.fromJson(decodeJsonObject('{"timezone":"UTC"}'));
      expect(minimal.dailyLimit.enabled, isFalse);
      expect(minimal.allowedHours.enabled, isFalse);
      expect(minimal.blockPeriods, isEmpty);
      expect(minimal.apps.rules, isEmpty);
      expect(minimal.web.managedBrowser, isTrue);
      expect(minimal.overrides.manualLock.active, isFalse);
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
        expect(() => LocalTime.parse(bad), throwsA(isA<JsonFormatException>()), reason: bad);
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
