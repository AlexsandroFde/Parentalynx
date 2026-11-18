import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/device_policy/device_policy_module.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/presentation/editing/policy_section_editor.dart';
import 'package:parentalynx/features/device_policy/presentation/editing/policy_section_state.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';
import '../support/limit_section.dart';

/// Ciclo comum das telas de regras: carregar, editar, descartar, salvar e acompanhar.
void main() {
  const String detailPath = '/v1/guardian/devices/$deviceId';
  const String policyPath = '/v1/guardian/devices/$deviceId/policy';

  late FakeBackend backend;
  late PolicySectionEditor<DailyLimit> editor;

  setUp(() {
    backend = FakeBackend();
    installStandardRoutes(backend);
    final TestDependencies deps = TestDependencies(backend: backend, sessionToken: 'gs_teste');
    addTearDown(deps.dispose);
    editor = createPolicySectionEditor(deps.di, const TestLimitSection());
  });

  DailyLimit disable(DailyLimit limit) => limit.copyWith(enabled: false);

  test('carrega a secao, marca alteracoes e descarta', () async {
    final PolicySectionState<DailyLimit> loaded = await editor.load(deviceId);
    expect(loaded, isA<PolicySectionEditing<DailyLimit>>());
    final PolicySectionEditing<DailyLimit> editing = loaded as PolicySectionEditing<DailyLimit>;
    expect(editing.base.version, 12);
    expect(editing.isDirty, isFalse);

    final PolicySectionEditing<DailyLimit> changed =
        editor.edit(editing, disable) as PolicySectionEditing<DailyLimit>;
    expect(changed.isDirty, isTrue);
    expect(changed.draft.enabled, isFalse);

    final PolicySectionEditing<DailyLimit> discarded =
        editor.discard(changed) as PolicySectionEditing<DailyLimit>;
    expect(discarded.isDirty, isFalse);
  });

  test('falha ao carregar vira estado de erro com a falha', () async {
    backend.onError('GET', detailPath, status: 500, code: 'internal');
    final PolicySectionState<DailyLimit> state = await editor.load(deviceId);
    expect(state, isA<PolicySectionError<DailyLimit>>());
    expect((state as PolicySectionError<DailyLimit>).failure, isA<ApiFailure>());
  });

  test('sem alteracoes nao ha o que salvar', () async {
    final PolicySectionState<DailyLimit> loaded = await editor.load(deviceId);
    expect(editor.startSaving(loaded), isNull);
  });

  test('salvar adota a versao nova e marca o envio', () async {
    backend.onJson('PUT', policyPath, <String, Object?>{
      'policyVersion': 13,
      'policy': policyJson(limitEnabled: false),
    });
    final PolicySectionState<DailyLimit> loaded = await editor.load(deviceId);
    final PolicySectionEditing<DailyLimit> saving = editor.startSaving(
      editor.edit(loaded, disable),
    )!;
    expect(saving.isSaving, isTrue);

    final PolicySectionEditing<DailyLimit> saved =
        await editor.save(saving) as PolicySectionEditing<DailyLimit>;
    expect(saved.status, SectionSaveStatus.saved);
    expect(saved.base.version, 13);
    expect(saved.isDirty, isFalse);
  });

  test('falha ao salvar mantem o rascunho e guarda a falha', () async {
    backend.onError('PUT', policyPath, status: 500, code: 'internal');
    final PolicySectionState<DailyLimit> loaded = await editor.load(deviceId);
    final PolicySectionEditing<DailyLimit> failed = await editor.save(
      editor.startSaving(editor.edit(loaded, disable))!,
    ) as PolicySectionEditing<DailyLimit>;
    expect(failed.status, SectionSaveStatus.failed);
    expect(failed.failure, isA<ApiFailure>());
    expect(failed.isDirty, isTrue);
  });

  test('conflito na mesma secao carrega a versao do servidor e avisa', () async {
    bool conflicted = false;
    backend
      ..on('GET', detailPath, (http.Request request) {
        return jsonResponse(<String, Object?>{
          'device': deviceJson(policyVersion: conflicted ? 13 : 12),
          'policyVersion': conflicted ? 13 : 12,
          'policy': policyJson(minutes: conflicted ? 60 : 150),
        });
      })
      ..on('PUT', policyPath, (http.Request request) {
        conflicted = true;
        return errorResponse(409, 'version_conflict');
      });
    final PolicySectionState<DailyLimit> loaded = await editor.load(deviceId);
    final PolicySectionEditing<DailyLimit> result = await editor.save(
      editor.startSaving(editor.edit(loaded, disable))!,
    ) as PolicySectionEditing<DailyLimit>;

    expect(result.status, SectionSaveStatus.conflict);
    expect(result.base.version, 13);
    expect(result.draft.minutes, 60);
    expect(result.isDirty, isFalse);
  });

  group('versao nova no servidor durante a edicao', () {
    void serverAt(int version, {required int minutes, Map<String, Object?>? protection}) {
      backend.on('GET', detailPath, (http.Request request) {
        final Map<String, Object?> policy = policyJson(minutes: minutes);
        if (protection != null) {
          policy['protection'] = protection;
        }
        return jsonResponse(<String, Object?>{
          'device': deviceJson(policyVersion: version),
          'policyVersion': version,
          'policy': policy,
        });
      });
    }

    test('sem alteracoes locais, adota a versao nova', () async {
      final PolicySectionState<DailyLimit> loaded = await editor.load(deviceId);
      serverAt(13, minutes: 60);
      final PolicySectionEditing<DailyLimit> followed =
          (await editor.follow(loaded, 13))! as PolicySectionEditing<DailyLimit>;
      expect(followed.base.version, 13);
      expect(followed.draft.minutes, 60);
    });

    test(
      'com alteracoes e secao igual no servidor, mantem o rascunho sobre a versao nova',
      () async {
        final PolicySectionState<DailyLimit> edited = editor.edit(
          await editor.load(deviceId),
          disable,
        );
        serverAt(13, minutes: 150, protection: <String, Object?>{'lockOnTamper': true});
        final PolicySectionEditing<DailyLimit> followed =
            (await editor.follow(edited, 13))! as PolicySectionEditing<DailyLimit>;
        expect(followed.base.version, 13);
        expect(followed.draft.enabled, isFalse);
        expect(followed.isDirty, isTrue);
      },
    );

    test('com alteracoes e secao mudada no servidor, nada muda ate salvar', () async {
      final PolicySectionState<DailyLimit> edited = editor.edit(
        await editor.load(deviceId),
        disable,
      );
      serverAt(13, minutes: 60);
      expect(await editor.follow(edited, 13), isNull);
    });

    test('versao igual ou antiga e ignorada', () async {
      final PolicySectionState<DailyLimit> loaded = await editor.load(deviceId);
      expect(await editor.follow(loaded, 12), isNull);
    });
  });
}
