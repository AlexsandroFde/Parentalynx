import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/guardian/rules/presentation/policy_editor.dart';
import 'package:parentalynx/shared/domain/policy.dart';

import '../dashboard/support/guardian_fixtures.dart';

void main() {
  const String detailRoute = 'GET /v1/guardian/devices/$deviceId';
  const String policyRoute = 'PUT /v1/guardian/devices/$deviceId/policy';

  Future<ProviderContainer> containerFor(FakeApi api) async {
    final ProviderContainer container = ProviderContainer(overrides: api.overrides);
    addTearDown(container.dispose);
    await container.read(policyEditorProvider(deviceId).future);
    return container;
  }

  Policy disableLimit(Policy policy) {
    return policy.copyWith(dailyLimit: policy.dailyLimit.copyWith(enabled: false));
  }

  test('carrega a politica, marca alteracoes e descarta', () async {
    final FakeApi api = FakeApi(standardRoutes());
    final ProviderContainer container = await containerFor(api);
    final PolicyEditor editor = container.read(policyEditorProvider(deviceId).notifier);

    PolicyEditorState state = container.read(policyEditorProvider(deviceId)).requireValue;
    expect(state.saved.version, 12);
    expect(state.isDirty, isFalse);

    editor.edit(disableLimit);
    state = container.read(policyEditorProvider(deviceId)).requireValue;
    expect(state.isDirty, isTrue);
    expect(state.draft.dailyLimit.enabled, isFalse);

    editor.discard();
    expect(container.read(policyEditorProvider(deviceId)).requireValue.isDirty, isFalse);
  });

  test('salvar envia a versao base e a politica sem os comandos', () async {
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      policyRoute: (http.Request request) => <String, Object?>{
        'policyVersion': 13,
        'policy': policyJson(limitEnabled: false),
      },
    });
    final ProviderContainer container = await containerFor(api);
    final PolicyEditor editor = container.read(policyEditorProvider(deviceId).notifier)
      ..edit(disableLimit);

    expect(await editor.save(), PolicySaveResult.saved);

    final Map<String, Object?> body = api.bodyOf(api.calls(policyRoute).single);
    expect(body['baseVersion'], 12);
    final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
    expect(sent.containsKey('overrides'), isFalse);
    expect((sent['dailyLimit']! as Map<String, Object?>)['enabled'], isFalse);
    final PolicyEditorState state = container.read(policyEditorProvider(deviceId)).requireValue;
    expect(state.saved.version, 13);
    expect(state.isDirty, isFalse);
    expect(state.saving, isFalse);
  });

  test('falha ao salvar mantem o rascunho e repassa o erro', () async {
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      policyRoute: (http.Request request) => errorResponse('elevation_required', 403),
    });
    final ProviderContainer container = await containerFor(api);
    final PolicyEditor editor = container.read(policyEditorProvider(deviceId).notifier)
      ..edit(disableLimit);

    await expectLater(
      editor.save(),
      throwsA(isA<ApiFailure>().having((ApiFailure f) => f.isElevationRequired, 'elevacao', true)),
    );
    final PolicyEditorState state = container.read(policyEditorProvider(deviceId)).requireValue;
    expect(state.isDirty, isTrue);
    expect(state.saving, isFalse);
  });

  test('conflito causado so por comandos reenvia sobre a versao nova', () async {
    int puts = 0;
    bool conflicted = false;
    final Map<String, Object?> overridesWithExtra = <String, Object?>{
      'extraTime': <Object?>[
        <String, Object?>{'id': 'e1', 'day': fixtureToday, 'minutes': 30, 'grantedAt': 1},
      ],
      'manualLock': <String, Object?>{'active': false},
      'suspension': <String, Object?>{'until': 0, 'scopes': <String>[]},
    };
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      detailRoute: (http.Request request) => <String, Object?>{
        'device': deviceJson(policyVersion: conflicted ? 13 : 12),
        'policyVersion': conflicted ? 13 : 12,
        'policy': policyJson(overrides: conflicted ? overridesWithExtra : null),
      },
      policyRoute: (http.Request request) {
        puts += 1;
        if (puts == 1) {
          conflicted = true;
          return errorResponse('version_conflict', 409, <String, Object?>{'currentVersion': 13});
        }
        return <String, Object?>{'policyVersion': 14, 'policy': policyJson(limitEnabled: false)};
      },
    });
    final ProviderContainer container = await containerFor(api);
    final PolicyEditor editor = container.read(policyEditorProvider(deviceId).notifier)
      ..edit(disableLimit);

    expect(await editor.save(), PolicySaveResult.saved);

    final List<http.Request> calls = api.calls(policyRoute);
    expect(calls, hasLength(2));
    expect(api.bodyOf(calls[1])['baseVersion'], 13);
    expect(container.read(policyEditorProvider(deviceId)).requireValue.saved.version, 14);
  });

  test('conflito com regras alteradas em outra sessao recarrega e avisa', () async {
    bool conflicted = false;
    final FakeApi api = FakeApi(<String, RouteHandler>{
      ...standardRoutes(),
      detailRoute: (http.Request request) => <String, Object?>{
        'device': deviceJson(policyVersion: conflicted ? 13 : 12),
        'policyVersion': conflicted ? 13 : 12,
        'policy': policyJson(minutes: conflicted ? 60 : 150),
      },
      policyRoute: (http.Request request) {
        conflicted = true;
        return errorResponse('version_conflict', 409);
      },
    });
    final ProviderContainer container = await containerFor(api);
    final PolicyEditor editor = container.read(policyEditorProvider(deviceId).notifier)
      ..edit(disableLimit);

    expect(await editor.save(), PolicySaveResult.conflictReloaded);

    final PolicyEditorState state = container.read(policyEditorProvider(deviceId)).requireValue;
    expect(api.calls(policyRoute), hasLength(1));
    expect(state.saved.version, 13);
    expect(state.draft.dailyLimit.minutes, 60);
    expect(state.isDirty, isFalse);
  });

  test('comparacao de politicas ignora os comandos', () {
    const Policy base = Policy(timezone: 'UTC');
    final Policy withLock = base.copyWith(
      overrides: const PolicyOverrides(manualLock: ManualLock(active: true)),
    );
    expect(sameEditablePolicy(base, withLock), isTrue);
    expect(sameEditablePolicy(base, base.copyWith(timezone: 'America/Fortaleza')), isFalse);
  });
}
