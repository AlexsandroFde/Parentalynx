import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/app_management/app_management_module.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_entry.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_list_filter.dart';
import 'package:parentalynx/features/app_management/domain/services/app_rules_editing.dart';
import 'package:parentalynx/features/app_management/presentation/bloc/app_inventory/app_inventory_bloc.dart';
import 'package:parentalynx/features/app_management/presentation/bloc/app_management/app_management_bloc.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_policy/presentation/editing/policy_section_state.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String policyPath = '/v1/guardian/devices/$deviceId/policy';
  const String appsPath = '/v1/guardian/devices/$deviceId/apps';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerAppManagementModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  group('AppManagementBloc', () {
    TypeMatcher<PolicySectionEditing<AppsPolicy>> editing() {
      return isA<PolicySectionEditing<AppsPolicy>>();
    }

    Future<void> start(AppManagementBloc bloc) async {
      bloc.add(const AppManagementStarted(deviceId));
      await bloc.stream.firstWhere(
        (AppManagementState state) => state is PolicySectionEditing<AppsPolicy>,
      );
    }

    const KnownApp tiktok = (package: 'com.zhiliaoapp.musically', system: false, essential: false);
    const KnownApp duolingo = (package: 'com.duolingo', system: false, essential: false);
    const KnownApp dialer = (package: 'com.android.dialer', system: true, essential: true);

    blocTest<AppManagementBloc, AppManagementState>(
      'trocar a regra de um app, aplicar a varios e bloquear apps novos',
      build: () => deps.di<AppManagementBloc>(),
      act: (AppManagementBloc bloc) async {
        await start(bloc);
        bloc
          ..add(const AppRuleChanged(app: tiktok, rule: AppRule.defaultAllowed))
          ..add(
            const AppRulesAppliedToMany(
              apps: <KnownApp>[duolingo, dialer],
              state: AppRuleState.blocked,
            ),
          )
          ..add(
            const NewAppDefaultChanged(
              value: NewAppDefault.blocked,
              installedApps: <KnownApp>[tiktok, duolingo, dialer],
            ),
          );
      },
      skip: 2,
      expect: () => <Matcher>[
        editing()
            .having(
              (PolicySectionEditing<AppsPolicy> s) => s.draft.rules.containsKey(tiktok.package),
              'regra redundante removida',
              isFalse,
            )
            .having((PolicySectionEditing<AppsPolicy> s) => s.isDirty, 'alterado', isTrue),
        editing()
            .having(
              (PolicySectionEditing<AppsPolicy> s) => s.draft.rules[duolingo.package]?.state,
              'duolingo',
              AppRuleState.blocked,
            )
            .having(
              (PolicySectionEditing<AppsPolicy> s) => s.draft.rules.containsKey(dialer.package),
              'essencial ignorado',
              isFalse,
            ),
        editing()
            .having(
              (PolicySectionEditing<AppsPolicy> s) => s.draft.defaultForNewApps,
              'apps novos',
              NewAppDefault.blocked,
            )
            .having(
              (PolicySectionEditing<AppsPolicy> s) => s.draft.rules[tiktok.package]?.state,
              'instalado continua permitido',
              AppRuleState.allowed,
            ),
      ],
    );

    blocTest<AppManagementBloc, AppManagementState>(
      'salvar envia as regras de apps e descartar volta ao salvo',
      setUp: () {
        deps.backend.onJson('PUT', policyPath, <String, Object?>{
          'policyVersion': 13,
          'policy': policyJson(rules: <String, Object?>{}),
        });
      },
      build: () => deps.di<AppManagementBloc>(),
      act: (AppManagementBloc bloc) async {
        await start(bloc);
        bloc
          ..add(const AppRuleChanged(app: tiktok, rule: AppRule.defaultAllowed))
          ..add(const AppManagementDiscardRequested())
          ..add(const AppRuleChanged(app: tiktok, rule: AppRule.defaultAllowed))
          ..add(const AppManagementSaveRequested());
        await bloc.stream.firstWhere(
          (AppManagementState state) =>
              state is PolicySectionEditing<AppsPolicy> && state.status == SectionSaveStatus.saved,
        );
      },
      skip: 3,
      expect: () => <Matcher>[
        editing().having((PolicySectionEditing<AppsPolicy> s) => s.isDirty, 'descartado', isFalse),
        editing().having((PolicySectionEditing<AppsPolicy> s) => s.isDirty, 'alterado', isTrue),
        editing().having((PolicySectionEditing<AppsPolicy> s) => s.isSaving, 'enviando', isTrue),
        editing()
            .having((PolicySectionEditing<AppsPolicy> s) => s.base.version, 'versao', 13)
            .having((PolicySectionEditing<AppsPolicy> s) => s.draft.rules, 'regras', isEmpty),
      ],
      verify: (_) {
        final Map<String, Object?> body = deps.backend.lastBody('PUT', policyPath);
        final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
        final Map<String, Object?> apps = sent['apps']! as Map<String, Object?>;
        final Map<String, Object?> rules = apps['rules']! as Map<String, Object?>;
        expect(rules.containsKey(tiktok.package), isFalse);
        expect(rules.containsKey('com.whatsapp'), isTrue);
      },
    );
  });

  group('AppInventoryBloc', () {
    blocTest<AppInventoryBloc, AppInventoryState>(
      'carrega o inventario ja filtrado pela categoria pedida e troca os filtros',
      build: () => deps.di<AppInventoryBloc>(),
      act: (AppInventoryBloc bloc) async {
        bloc.add(
          const AppInventoryStarted(deviceId: deviceId, initialCategory: AppCategory.browser),
        );
        await bloc.stream.firstWhere((AppInventoryState state) => state is AppInventoryLoaded);
        bloc
          ..add(const AppListQueryChanged('chr'))
          ..add(const AppListStateFilterChanged(AppStateFilter.blocked))
          ..add(const AppListCategoryChanged(null));
      },
      expect: () => <Matcher>[
        isA<AppInventoryLoading>().having(
          (AppInventoryLoading s) => s.filter.category,
          'categoria',
          AppCategory.browser,
        ),
        isA<AppInventoryLoaded>()
            .having((AppInventoryLoaded s) => s.appsOrEmpty, 'apps', hasLength(7))
            .having((AppInventoryLoaded s) => s.filter.category, 'categoria', AppCategory.browser),
        isA<AppInventoryLoaded>().having((AppInventoryLoaded s) => s.filter.query, 'busca', 'chr'),
        isA<AppInventoryLoaded>().having(
          (AppInventoryLoaded s) => s.filter.state,
          'estado',
          AppStateFilter.blocked,
        ),
        isA<AppInventoryLoaded>()
            .having((AppInventoryLoaded s) => s.filter.category, 'todas', isNull)
            .having((AppInventoryLoaded s) => s.filter.isNarrowed, 'filtrado', isTrue),
      ],
    );

    blocTest<AppInventoryBloc, AppInventoryState>(
      'falha ao carregar mostra o erro e tentar de novo recarrega',
      setUp: () {
        deps.backend.onError('GET', appsPath, status: 500, code: 'internal');
      },
      build: () => deps.di<AppInventoryBloc>(),
      act: (AppInventoryBloc bloc) async {
        bloc.add(const AppInventoryStarted(deviceId: deviceId));
        await bloc.stream.firstWhere((AppInventoryState state) => state is AppInventoryError);
        deps.backend.onJson('GET', appsPath, appsJson());
        bloc.add(const AppInventoryRetryRequested());
        await bloc.stream.firstWhere((AppInventoryState state) => state is AppInventoryLoaded);
      },
      expect: () => <Matcher>[
        isA<AppInventoryLoading>(),
        isA<AppInventoryError>().having(
          (AppInventoryError s) => s.failure,
          'falha',
          isA<ApiFailure>(),
        ),
        isA<AppInventoryLoading>(),
        isA<AppInventoryLoaded>(),
      ],
    );
  });
}
