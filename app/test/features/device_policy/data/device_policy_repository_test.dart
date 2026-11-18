import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/domain/entities/versioned_policy.dart';
import 'package:parentalynx/features/device_policy/domain/repositories/i_device_policy_repository.dart';
import 'package:parentalynx/features/device_policy/domain/repositories/i_policy_command_repository.dart';

import '../../../support/fake_backend.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const Map<String, Object?> policyEnvelope = <String, Object?>{
    'policyVersion': 7,
    'policy': <String, Object?>{'timezone': 'America/Fortaleza'},
  };

  late FakeBackend backend;
  late TestDependencies deps;

  setUp(() {
    backend = FakeBackend();
    deps = TestDependencies(backend: backend, sessionToken: 'gs_abc');
    addTearDown(deps.dispose);
  });

  test('busca a politica do aparelho com a versao do servidor', () async {
    backend.onJson('GET', '/v1/guardian/devices/d1', <String, Object?>{
      'device': <String, Object?>{'id': 'd1'},
      ...policyEnvelope,
    });

    final VersionedPolicy policy = (await deps.di<IDevicePolicyRepository>().fetch('d1'))
        .valueOrNull!;

    expect(policy.version, 7);
    expect(policy.policy.timezone, 'America/Fortaleza');
  });

  test('grava a politica sem os comandos e com a versao base', () async {
    backend.onJson('PUT', '/v1/guardian/devices/d1/policy', policyEnvelope);
    const Policy policy = Policy(
      timezone: 'America/Fortaleza',
      dailyLimit: DailyLimit(enabled: true, minutes: 150),
    );

    final Result<VersionedPolicy> saved = await deps.di<IDevicePolicyRepository>().replace(
      'd1',
      baseVersion: 6,
      policy: policy,
    );

    expect(saved.valueOrNull!.version, 7);
    final Map<String, Object?> body = backend.lastBody('PUT', '/v1/guardian/devices/d1/policy');
    expect(body['baseVersion'], 6);
    final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
    expect(sent.containsKey('overrides'), isFalse);
    expect((sent['dailyLimit']! as Map<String, Object?>)['minutes'], 150);
  });

  test('comandos usam a rota e o corpo do protocolo', () async {
    for (final String path in <String>['extra-time', 'lock', 'unlock', 'suspension']) {
      backend.onJson('POST', '/v1/guardian/devices/d1/$path', policyEnvelope);
    }
    backend.onJson('DELETE', '/v1/guardian/devices/d1/suspension', policyEnvelope);
    final IPolicyCommandRepository commands = deps.di<IPolicyCommandRepository>();

    await commands.grantExtraTime('d1', minutes: 30);
    await commands.lock('d1');
    await commands.lock('d1', until: 5000);
    await commands.unlock('d1');
    await commands.suspend(
      'd1',
      minutes: 60,
      scopes: <SuspensionScope>[SuspensionScope.dailyLimit, SuspensionScope.schedules],
    );
    await commands.clearSuspension('d1');

    final List<http.Request> requests = backend.requests;
    expect(requests.map((http.Request r) => '${r.method} ${r.url.path}'), <String>[
      'POST /v1/guardian/devices/d1/extra-time',
      'POST /v1/guardian/devices/d1/lock',
      'POST /v1/guardian/devices/d1/lock',
      'POST /v1/guardian/devices/d1/unlock',
      'POST /v1/guardian/devices/d1/suspension',
      'DELETE /v1/guardian/devices/d1/suspension',
    ]);
    expect(jsonDecode(requests[0].body), <String, Object?>{'minutes': 30});
    expect(jsonDecode(requests[1].body), <String, Object?>{'until': null});
    expect(jsonDecode(requests[2].body), <String, Object?>{'until': 5000});
    expect(jsonDecode(requests[4].body), <String, Object?>{
      'minutes': 60,
      'scopes': <String>['dailyLimit', 'schedules'],
    });
  });

  test('conflito de versao chega como ApiFailure identificavel', () async {
    backend.onError(
      'PUT',
      '/v1/guardian/devices/d1/policy',
      status: 409,
      code: 'version_conflict',
      details: <String, Object?>{'currentVersion': 9},
    );

    final Result<VersionedPolicy> result = await deps.di<IDevicePolicyRepository>().replace(
      'd1',
      baseVersion: 6,
      policy: const Policy(timezone: 'UTC'),
    );

    expect(
      result.failureOrNull,
      isA<ApiFailure>().having((ApiFailure f) => f.isVersionConflict, 'conflito', isTrue),
    );
  });
}
