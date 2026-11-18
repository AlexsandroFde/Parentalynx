import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy_save_outcome.dart';
import 'package:parentalynx/features/device_policy/domain/entities/versioned_policy.dart';
import 'package:parentalynx/features/device_policy/domain/usecases/get_device_policy.dart';
import 'package:parentalynx/features/device_policy/domain/usecases/save_policy_section.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';
import '../support/limit_section.dart';

/// Salvamento de uma secao da politica com concorrencia otimista, contra o servidor falso.
void main() {
  const String detailPath = '/v1/guardian/devices/$deviceId';
  const String policyPath = '/v1/guardian/devices/$deviceId/policy';

  late FakeBackend backend;

  TestDependencies build({FakeElevationPrompter? prompter}) {
    final TestDependencies deps = TestDependencies(
      backend: backend,
      sessionToken: 'gs_teste',
      elevationPrompter: prompter,
    );
    addTearDown(deps.dispose);
    return deps;
  }

  Future<VersionedPolicy> load(TestDependencies deps) async {
    return (await deps.di<GetDevicePolicy>()(deviceId)).valueOrNull!;
  }

  Map<String, Object?> bodyOf(http.Request request) {
    return jsonDecode(request.body) as Map<String, Object?>;
  }

  setUp(() {
    backend = FakeBackend();
    installStandardRoutes(backend);
  });

  test('envia a versao base e a politica sem os comandos', () async {
    backend.onJson('PUT', policyPath, <String, Object?>{
      'policyVersion': 13,
      'policy': policyJson(limitEnabled: false),
    });
    final TestDependencies deps = build();
    final VersionedPolicy base = await load(deps);

    final Result<PolicySaveOutcome> result = await deps.di<SavePolicySection>()<DailyLimit>(
      deviceId: deviceId,
      base: base,
      value: base.policy.dailyLimit.copyWith(enabled: false),
      section: const TestLimitSection(),
    );

    expect(result.valueOrNull, isA<PolicySaved>());
    expect((result.valueOrNull! as PolicySaved).policy.version, 13);
    final Map<String, Object?> body = backend.lastBody('PUT', policyPath);
    expect(body['baseVersion'], 12);
    final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
    expect(sent.containsKey('overrides'), isFalse);
    expect((sent['dailyLimit']! as Map<String, Object?>)['enabled'], isFalse);
  });

  test('pede a senha quando o servidor exige e repete o envio', () async {
    int puts = 0;
    backend.on('PUT', policyPath, (http.Request request) {
      puts += 1;
      if (puts == 1) {
        return errorResponse(403, 'elevation_required');
      }
      return jsonResponse(<String, Object?>{'policyVersion': 13, 'policy': policyJson()});
    });
    final FakeElevationPrompter prompter = FakeElevationPrompter();
    final TestDependencies deps = build(prompter: prompter);
    final VersionedPolicy base = await load(deps);

    final Result<PolicySaveOutcome> result = await deps.di<SavePolicySection>()<DailyLimit>(
      deviceId: deviceId,
      base: base,
      value: base.policy.dailyLimit.copyWith(minutes: 60),
      section: const TestLimitSection(),
    );

    expect(result.valueOrNull, isA<PolicySaved>());
    expect(prompter.requests, 1);
    expect(backend.calls('PUT', policyPath), hasLength(2));
  });

  test('desistir da senha devolve cancelamento e nao repete', () async {
    backend.onError('PUT', policyPath, status: 403, code: 'elevation_required');
    final TestDependencies deps = build(prompter: FakeElevationPrompter(accept: false));
    final VersionedPolicy base = await load(deps);

    final Result<PolicySaveOutcome> result = await deps.di<SavePolicySection>()<DailyLimit>(
      deviceId: deviceId,
      base: base,
      value: base.policy.dailyLimit.copyWith(minutes: 60),
      section: const TestLimitSection(),
    );

    expect(result.failureOrNull, isA<CancelledFailure>());
    expect(backend.calls('PUT', policyPath), hasLength(1));
  });

  group('conflito de versao', () {
    /// O servidor recusa o primeiro envio porque outra sessao gravou a versao 13 com
    /// [remotePolicy]; o segundo envio e aceito como versao 14.
    void conflictWith(Map<String, Object?> remotePolicy) {
      bool conflicted = false;
      int puts = 0;
      backend
        ..on('GET', detailPath, (http.Request request) {
          return jsonResponse(<String, Object?>{
            'device': deviceJson(policyVersion: conflicted ? 13 : 12),
            'policyVersion': conflicted ? 13 : 12,
            'policy': conflicted ? remotePolicy : policyJson(),
          });
        })
        ..on('PUT', policyPath, (http.Request request) {
          puts += 1;
          if (puts == 1) {
            conflicted = true;
            return errorResponse(409, 'version_conflict');
          }
          return jsonResponse(<String, Object?>{'policyVersion': 14, 'policy': remotePolicy});
        });
    }

    test('so os comandos mudaram: reenvia sobre a versao nova', () async {
      conflictWith(
        policyJson(
          overrides: <String, Object?>{
            'extraTime': <Object?>[
              <String, Object?>{'id': 'e1', 'day': fixtureToday, 'minutes': 30, 'grantedAt': 1},
            ],
            'manualLock': <String, Object?>{'active': false},
            'suspension': <String, Object?>{'until': 0, 'scopes': <String>[]},
          },
        ),
      );
      final TestDependencies deps = build();
      final VersionedPolicy base = await load(deps);

      final Result<PolicySaveOutcome> result = await deps.di<SavePolicySection>()<DailyLimit>(
        deviceId: deviceId,
        base: base,
        value: base.policy.dailyLimit.copyWith(enabled: false),
        section: const TestLimitSection(),
      );

      expect(result.valueOrNull, isA<PolicySaved>());
      final List<http.Request> puts = backend.calls('PUT', policyPath);
      expect(puts, hasLength(2));
      expect(bodyOf(puts[1])['baseVersion'], 13);
    });

    test('outra secao mudou: aplica a secao editada sobre a versao nova', () async {
      final Map<String, Object?> remote = policyJson()
        ..['protection'] = <String, Object?>{'lockOnTamper': true};
      conflictWith(remote);
      final TestDependencies deps = build();
      final VersionedPolicy base = await load(deps);

      final Result<PolicySaveOutcome> result = await deps.di<SavePolicySection>()<DailyLimit>(
        deviceId: deviceId,
        base: base,
        value: base.policy.dailyLimit.copyWith(minutes: 90),
        section: const TestLimitSection(),
      );

      expect(result.valueOrNull, isA<PolicySaved>());
      final Map<String, Object?> sent =
          bodyOf(backend.calls('PUT', policyPath)[1])['policy']! as Map<String, Object?>;
      // A protecao gravada pela outra sessao continua; o limite editado aqui vai junto.
      expect((sent['protection']! as Map<String, Object?>)['lockOnTamper'], isTrue);
      expect((sent['dailyLimit']! as Map<String, Object?>)['minutes'], 90);
    });

    test('a mesma secao mudou: nao grava e devolve a versao atual', () async {
      conflictWith(policyJson(minutes: 60));
      final TestDependencies deps = build();
      final VersionedPolicy base = await load(deps);

      final Result<PolicySaveOutcome> result = await deps.di<SavePolicySection>()<DailyLimit>(
        deviceId: deviceId,
        base: base,
        value: base.policy.dailyLimit.copyWith(enabled: false),
        section: const TestLimitSection(),
      );

      final PolicySaveOutcome outcome = result.valueOrNull!;
      expect(outcome, isA<PolicyConflict>());
      expect((outcome as PolicyConflict).latest.version, 13);
      expect(outcome.latest.policy.dailyLimit.minutes, 60);
      expect(backend.calls('PUT', policyPath), hasLength(1));
    });

    test('secao diferente da editada nao conta como conflito', () async {
      conflictWith(policyJson(minutes: 60));
      final TestDependencies deps = build();
      final VersionedPolicy base = await load(deps);

      final Result<PolicySaveOutcome> result = await deps.di<SavePolicySection>()<ProtectionPolicy>(
        deviceId: deviceId,
        base: base,
        value: base.policy.protection.copyWith(lockOnTamper: true),
        section: const TestProtectionSection(),
      );

      expect(result.valueOrNull, isA<PolicySaved>());
    });
  });
}
