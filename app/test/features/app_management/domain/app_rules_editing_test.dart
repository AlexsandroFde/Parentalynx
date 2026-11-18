import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_entry.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_list_filter.dart';
import 'package:parentalynx/features/app_management/domain/entities/effective_app_state.dart';
import 'package:parentalynx/features/app_management/domain/services/app_list_query.dart';
import 'package:parentalynx/features/app_management/domain/services/app_rules_editing.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';

AppEntry _app(
  String package,
  String label, {
  AppCategory category = AppCategory.games,
  bool system = false,
  bool launchable = true,
  bool essential = false,
  bool removed = false,
}) {
  return AppEntry(
    package: package,
    label: label,
    category: category,
    system: system,
    launchable: launchable,
    essential: essential,
    state: AppRuleState.allowed,
    countsTowardLimit: false,
    todayMs: 0,
    weekMs: 0,
    removed: removed,
  );
}

void main() {
  group('regras por app', () {
    const AppRule blocked = AppRule(state: AppRuleState.blocked);

    test('estado efetivo segue a regra, o padrao de apps novos e os essenciais', () {
      const AppsPolicy open = AppsPolicy(rules: <String, AppRule>{'com.jogo': blocked});
      expect(
        effectiveAppState(open, package: 'com.jogo', system: false, essential: false),
        EffectiveAppState.blocked,
      );
      expect(
        effectiveAppState(open, package: 'com.outro', system: false, essential: false),
        EffectiveAppState.allowed,
      );
      expect(
        effectiveAppState(open, package: 'com.jogo', system: false, essential: true),
        EffectiveAppState.essential,
      );

      const AppsPolicy strict = AppsPolicy(defaultForNewApps: NewAppDefault.blocked);
      expect(
        effectiveAppState(strict, package: 'com.novo', system: false, essential: false),
        EffectiveAppState.pendingApproval,
      );
      expect(
        effectiveAppState(strict, package: 'com.android.chrome', system: true, essential: false),
        EffectiveAppState.allowed,
      );
      expect(EffectiveAppState.pendingApproval.isBlocked, isTrue);
    });

    test('regra padrao nao e gravada quando apps novos sao permitidos', () {
      final AppsPolicy apps = setAppRule(const AppsPolicy(), 'com.jogo', blocked, system: false);
      expect(apps.rules.keys, <String>['com.jogo']);
      final AppsPolicy back = setAppRule(apps, 'com.jogo', AppRule.defaultAllowed, system: false);
      expect(back.rules, isEmpty);
    });

    test('com apps novos bloqueados, permitir fica gravado como aprovacao', () {
      const AppsPolicy strict = AppsPolicy(defaultForNewApps: NewAppDefault.blocked);
      final AppsPolicy approved = setAppRule(
        strict,
        'com.novo',
        AppRule.defaultAllowed,
        system: false,
      );
      expect(approved.rules['com.novo']?.state, AppRuleState.allowed);
      expect(
        effectiveAppState(approved, package: 'com.novo', system: false, essential: false),
        EffectiveAppState.allowed,
      );
    });

    test('ligar o bloqueio de apps novos preserva os apps ja instalados', () {
      const List<KnownApp> known = <KnownApp>[
        (package: 'com.jogo', system: false, essential: false),
        (package: 'com.escola', system: false, essential: false),
        (package: 'com.android.chrome', system: true, essential: false),
        (package: 'com.android.dialer', system: true, essential: true),
      ];
      const AppsPolicy before = AppsPolicy(rules: <String, AppRule>{'com.jogo': blocked});

      final AppsPolicy strict = setNewAppDefault(before, NewAppDefault.blocked, knownApps: known);

      expect(strict.defaultForNewApps, NewAppDefault.blocked);
      expect(strict.rules['com.jogo']?.state, AppRuleState.blocked);
      expect(strict.rules['com.escola']?.state, AppRuleState.allowed);
      expect(strict.rules.containsKey('com.android.chrome'), isFalse);
      expect(
        effectiveAppState(strict, package: 'com.instalado.depois', system: false, essential: false),
        EffectiveAppState.pendingApproval,
      );

      final AppsPolicy open = setNewAppDefault(strict, NewAppDefault.allowed, knownApps: known);
      expect(open.rules.keys, <String>['com.jogo']);
    });

    test('aplicar a varios ignora os essenciais', () {
      final AppsPolicy apps = setStateForMany(const AppsPolicy(), const <KnownApp>[
        (package: 'com.a', system: false, essential: false),
        (package: 'com.android.dialer', system: true, essential: true),
      ], AppRuleState.blocked);
      expect(apps.rules.keys, <String>['com.a']);
    });

    test('folha do app: contar na cota so vale para excecao e bloqueado nao tem limite', () {
      expect(
        composeAppRule(state: AppRuleState.allowed, countsTowardLimit: true, dailyLimitMinutes: 30),
        const AppRule(state: AppRuleState.allowed, dailyLimitMinutes: 30),
      );
      expect(
        composeAppRule(
          state: AppRuleState.exception,
          countsTowardLimit: true,
          dailyLimitMinutes: null,
        ),
        const AppRule(state: AppRuleState.exception, countsTowardLimit: true),
      );
      expect(
        composeAppRule(state: AppRuleState.blocked, countsTowardLimit: true, dailyLimitMinutes: 30),
        blocked,
      );
    });
  });

  group('lista de apps', () {
    final List<AppEntry> apps = <AppEntry>[
      _app('com.zeta', 'Zeta'),
      _app(
        'com.android.dialer',
        'Telefone',
        category: AppCategory.communication,
        system: true,
        essential: true,
      ),
      _app('com.alpha', 'alpha', category: AppCategory.video),
      _app('com.android.interno', 'Interno', system: true, launchable: false),
      _app('com.velho', 'Velho', removed: true),
      _app('com.removido', 'Removido com regra', removed: true),
    ];
    const AppsPolicy policy = AppsPolicy(
      rules: <String, AppRule>{
        'com.zeta': AppRule(state: AppRuleState.blocked),
        'com.removido': AppRule(state: AppRuleState.blocked),
        'com.alpha': AppRule(state: AppRuleState.exception),
      },
    );

    List<String> packages(AppListFilter filter) {
      return visibleApps(apps, policy, filter).map((AppEntry app) => app.package).toList();
    }

    test('mostra os apps do usuario e os com regra, em ordem, com os essenciais no fim', () {
      expect(packages(const AppListFilter()), <String>[
        'com.alpha',
        'com.removido',
        'com.zeta',
        'com.android.dialer',
      ]);
    });

    test('filtra por estado, categoria e busca', () {
      expect(packages(const AppListFilter(state: AppStateFilter.blocked)), <String>[
        'com.removido',
        'com.zeta',
      ]);
      expect(packages(const AppListFilter(category: AppCategory.video)), <String>['com.alpha']);
      expect(packages(const AppListFilter(query: 'TELE')), <String>['com.android.dialer']);
      expect(packages(const AppListFilter(query: 'com.zet')), <String>['com.zeta']);
    });

    test('categorias, excecoes e essenciais', () {
      expect(categoriesOf(apps), <AppCategory>{
        AppCategory.games,
        AppCategory.communication,
        AppCategory.video,
      });
      expect(exceptionRules(policy).map((MapEntry<String, AppRule> entry) => entry.key), <String>[
        'com.alpha',
      ]);
      expect(essentialApps(apps).map((AppEntry app) => app.package), <String>[
        'com.android.dialer',
      ]);
    });

    test('filtro sabe quando restringe a lista e volta para todas as categorias', () {
      expect(const AppListFilter(query: '  ').isNarrowed, isFalse);
      expect(const AppListFilter(state: AppStateFilter.pending).isNarrowed, isTrue);
      final AppListFilter games = const AppListFilter().copyWith(category: AppCategory.games);
      expect(games.isNarrowed, isTrue);
      expect(games.copyWith(allCategories: true).category, isNull);
      expect(AppStateFilter.pending.matches(EffectiveAppState.pendingApproval), isTrue);
      expect(AppStateFilter.allowed.matches(EffectiveAppState.essential), isFalse);
    });
  });
}
