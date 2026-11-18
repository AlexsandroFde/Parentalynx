import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/features/device_policy/data/dto/policy_dto.dart';
import 'package:parentalynx/features/device_policy/data/mappers/policy_mapper.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/domain/entities/versioned_policy.dart';

/// Exemplo completo do protocolo (secao 4.2).
const String fullPolicyJson = '''
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

Policy parsePolicy(String source) {
  return PolicyMapper.policy(PolicyDto.fromJson(decodeJsonObject(source)));
}

void main() {
  final Policy policy = parsePolicy(fullPolicyJson);

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
    expect(policy.web.mode, WebMode.allowlist);
    expect(policy.web.safeSearch, isFalse);
    expect(policy.protection.lockOnTamper, isTrue);
    expect(policy.overrides.manualLock.active, isTrue);
    expect(policy.overrides.suspension.scopes, <SuspensionScope>[
      SuspensionScope.dailyLimit,
      SuspensionScope.schedules,
    ]);
  });

  test('ida e volta por JSON preserva tudo', () {
    final String encoded = jsonEncode(PolicyMapper.toDto(policy).toJson());
    final Policy again = parsePolicy(encoded);
    expect(again, policy);
    expect(again.hashCode, policy.hashCode);
  });

  test('envio ao servidor omite os overrides', () {
    final PolicyDto dto = PolicyMapper.toDto(policy);
    expect(dto.toJson(includeOverrides: false).containsKey('overrides'), isFalse);
    expect(dto.toJson().containsKey('overrides'), isTrue);
  });

  test('regra de app so grava o que vale para o estado', () {
    final Map<String, Object?> rules =
        (PolicyMapper.toDto(policy).toJson()['apps']! as Map<String, Object?>)['rules']!
            as Map<String, Object?>;
    expect(rules['com.whatsapp'], <String, Object?>{
      'state': 'exception',
      'countsTowardLimit': false,
    });
    expect(rules['com.example.jogo'], <String, Object?>{'state': 'blocked'});
    expect(rules['com.google.android.youtube'], <String, Object?>{
      'state': 'allowed',
      'dailyLimitMinutes': 45,
    });
  });

  test('politica minima assume os padroes', () {
    final Policy minimal = parsePolicy('{"timezone":"UTC"}');
    expect(minimal.dailyLimit, DailyLimit.disabled);
    expect(minimal.allowedHours, AllowedHours.disabled);
    expect(minimal.blockPeriods, isEmpty);
    expect(minimal.apps.rules, isEmpty);
    expect(minimal.web, const WebPolicy());
    expect(minimal.overrides.manualLock.active, isFalse);
  });

  test('secao sem campos assume os padroes de cada campo', () {
    final Policy partial = parsePolicy('{"dailyLimit":{},"web":{},"overrides":{"suspension":{}}}');
    expect(partial.timezone, 'UTC');
    expect(partial.dailyLimit.minutes, 120);
    expect(partial.dailyLimit.warnAtMinutes, <int>[15, 5]);
    expect(partial.web.managedBrowser, isTrue);
    // Lista ausente na secao web vira lista vazia, como no protocolo.
    expect(partial.web.blockedCategories, isEmpty);
    expect(partial.overrides.suspension, Suspension.none);
  });

  test('escopo de suspensao desconhecido e ignorado', () {
    final Policy future = parsePolicy(
      '{"overrides":{"suspension":{"until":10,"scopes":["dailyLimit","novo"]}}}',
    );
    expect(future.overrides.suspension.scopes, <SuspensionScope>[SuspensionScope.dailyLimit]);
  });

  test('horario fora do formato vira resposta inesperada', () {
    expect(
      () => parsePolicy('{"dailyLimit":{"resetTime":"25:00"}}'),
      throwsA(isA<JsonFormatException>()),
    );
  });

  test('politica versionada le a versao do servidor', () {
    final VersionedPolicy versioned = PolicyMapper.versioned(
      VersionedPolicyDto.fromJson(
        const JsonMap(<String, Object?>{
          'policyVersion': 7,
          'policy': <String, Object?>{'timezone': 'UTC'},
        }),
      ),
    );
    expect(versioned.version, 7);
    expect(versioned.policy.timezone, 'UTC');
  });
}
