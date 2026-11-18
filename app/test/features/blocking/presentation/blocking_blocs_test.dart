import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/blocking/blocking_module.dart';
import 'package:parentalynx/features/blocking/domain/entities/system_lock.dart';
import 'package:parentalynx/features/blocking/domain/services/web_policy_editing.dart';
import 'package:parentalynx/features/blocking/presentation/bloc/protection/protection_bloc.dart';
import 'package:parentalynx/features/blocking/presentation/bloc/web_filter/web_filter_bloc.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/presentation/editing/policy_section_state.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String policyPath = '/v1/guardian/devices/$deviceId/policy';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerBlockingModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  group('ProtectionBloc', () {
    TypeMatcher<PolicySectionEditing<ProtectionPolicy>> editing() {
      return isA<PolicySectionEditing<ProtectionPolicy>>();
    }

    Future<void> start(ProtectionBloc bloc) async {
      bloc.add(const ProtectionStarted(deviceId));
      await bloc.stream.firstWhere(
        (ProtectionState state) => state is PolicySectionEditing<ProtectionPolicy>,
      );
    }

    blocTest<ProtectionBloc, ProtectionState>(
      'liga o bloqueio por adulteracao e as travas e envia so a secao de protecao',
      setUp: () {
        final Map<String, Object?> policy = policyJson()
          ..['protection'] = <String, Object?>{'lockOnTamper': true, 'blockUsbDebugging': true};
        deps.backend.onJson('PUT', policyPath, <String, Object?>{
          'policyVersion': 13,
          'policy': policy,
        });
      },
      build: () => deps.di<ProtectionBloc>(),
      act: (ProtectionBloc bloc) async {
        await start(bloc);
        bloc
          ..add(const ProtectionLockOnTamperChanged(true))
          ..add(const ProtectionSystemLockChanged(lock: SystemLock.usbDebugging, enabled: true))
          ..add(const ProtectionSaveRequested());
        await bloc.stream.firstWhere(
          (ProtectionState state) =>
              state is PolicySectionEditing<ProtectionPolicy> &&
              state.status == SectionSaveStatus.saved,
        );
      },
      skip: 2,
      expect: () => <Matcher>[
        editing().having(
          (PolicySectionEditing<ProtectionPolicy> s) => s.draft.lockOnTamper,
          'adulteracao',
          isTrue,
        ),
        editing().having(
          (PolicySectionEditing<ProtectionPolicy> s) => s.draft.blockUsbDebugging,
          'depuracao USB',
          isTrue,
        ),
        editing().having(
          (PolicySectionEditing<ProtectionPolicy> s) => s.isSaving,
          'enviando',
          isTrue,
        ),
        editing()
            .having((PolicySectionEditing<ProtectionPolicy> s) => s.base.version, 'versao', 13)
            .having((PolicySectionEditing<ProtectionPolicy> s) => s.isDirty, 'alterado', isFalse),
      ],
      verify: (_) {
        final Map<String, Object?> body = deps.backend.lastBody('PUT', policyPath);
        expect(body['baseVersion'], 12);
        final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
        final Map<String, Object?> protection = sent['protection']! as Map<String, Object?>;
        expect(protection['lockOnTamper'], isTrue);
        expect(protection['blockUsbDebugging'], isTrue);
      },
    );
  });

  group('WebFilterBloc', () {
    TypeMatcher<PolicySectionEditing<WebPolicy>> editing() {
      return isA<PolicySectionEditing<WebPolicy>>();
    }

    Future<void> start(WebFilterBloc bloc) async {
      bloc.add(const WebFilterStarted(deviceId));
      await bloc.stream.firstWhere(
        (WebFilterState state) => state is PolicySectionEditing<WebPolicy>,
      );
    }

    blocTest<WebFilterBloc, WebFilterState>(
      'navegador, modo, categorias e listas de sites entram no rascunho',
      build: () => deps.di<WebFilterBloc>(),
      act: (WebFilterBloc bloc) async {
        await start(bloc);
        bloc
          ..add(const WebSafeSearchChanged(false))
          ..add(const WebCategoryToggled(category: WebCategory.adult, blocked: false))
          ..add(const WebDomainAdded(list: WebDomainList.blocked, domain: 'jogos.com'))
          ..add(const WebModeChanged(WebMode.allowlist))
          ..add(const WebDomainAdded(list: WebDomainList.allowed, domain: 'escola.com.br'))
          ..add(const WebDomainRemoved(list: WebDomainList.blocked, domain: 'jogos.com'))
          ..add(const WebFilterDiscardRequested());
      },
      skip: 2,
      expect: () => <Matcher>[
        editing().having(
          (PolicySectionEditing<WebPolicy> s) => s.draft.safeSearch,
          'busca segura',
          isFalse,
        ),
        editing().having(
          (PolicySectionEditing<WebPolicy> s) => s.draft.blockedCategories,
          'categorias',
          <String>['gambling'],
        ),
        editing().having(
          (PolicySectionEditing<WebPolicy> s) => s.draft.blockedDomains,
          'bloqueados',
          <String>['jogos.com'],
        ),
        editing().having(
          (PolicySectionEditing<WebPolicy> s) => s.draft.mode,
          'modo',
          WebMode.allowlist,
        ),
        editing().having(
          (PolicySectionEditing<WebPolicy> s) => s.draft.allowedDomains,
          'autorizados',
          <String>['escola.com.br'],
        ),
        editing().having(
          (PolicySectionEditing<WebPolicy> s) => s.draft.blockedDomains,
          'bloqueados',
          isEmpty,
        ),
        editing()
            .having((PolicySectionEditing<WebPolicy> s) => s.isDirty, 'alterado', isFalse)
            .having((PolicySectionEditing<WebPolicy> s) => s.draft.mode, 'modo', WebMode.blocklist),
      ],
    );

    blocTest<WebFilterBloc, WebFilterState>(
      'salvar envia a politica de navegacao',
      setUp: () {
        deps.backend.onJson('PUT', policyPath, <String, Object?>{
          'policyVersion': 13,
          'policy': policyJson(),
        });
      },
      build: () => deps.di<WebFilterBloc>(),
      act: (WebFilterBloc bloc) async {
        await start(bloc);
        bloc
          ..add(const WebManagedBrowserChanged(false))
          ..add(const WebFilterSaveRequested());
        await bloc.stream.firstWhere(
          (WebFilterState state) =>
              state is PolicySectionEditing<WebPolicy> && state.status == SectionSaveStatus.saved,
        );
      },
      verify: (_) {
        final Map<String, Object?> body = deps.backend.lastBody('PUT', policyPath);
        final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
        final Map<String, Object?> web = sent['web']! as Map<String, Object?>;
        expect(web['managedBrowser'], isFalse);
      },
    );
  });
}
