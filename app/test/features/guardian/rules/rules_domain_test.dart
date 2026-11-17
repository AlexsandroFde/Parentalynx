import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/features/guardian/apps/domain/app_entry.dart';
import 'package:parentalynx/features/guardian/devices/domain/device.dart';
import 'package:parentalynx/features/guardian/rules/domain/allowed_hours_editing.dart';
import 'package:parentalynx/features/guardian/rules/domain/app_rules_editing.dart';
import 'package:parentalynx/features/guardian/rules/domain/ids.dart';
import 'package:parentalynx/features/guardian/rules/domain/policy_summaries.dart';
import 'package:parentalynx/shared/domain/policy.dart';

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
  });

  group('horarios permitidos', () {
    const AllowedHours hours = AllowedHours(
      enabled: true,
      windows: <TimeWindow>[
        TimeWindow(days: <int>[1, 2, 3, 4, 5], start: LocalTime(7, 0), end: LocalTime(20, 30)),
        TimeWindow(days: <int>[6], start: LocalTime(9, 0), end: LocalTime(12, 0)),
        TimeWindow(days: <int>[6], start: LocalTime(14, 0), end: LocalTime(22, 0)),
      ],
    );

    test('abre por dia e identifica os dias bloqueados', () {
      final WeekWindows week = expandAllowedHours(hours);
      expect(week[1], <DayWindow>[const DayWindow(LocalTime(7, 0), LocalTime(20, 30))]);
      expect(week[6], hasLength(2));
      expect(week[7], isEmpty);
      expect(blockedDays(week), <int>[7]);
    });

    test('ida e volta junta janelas iguais de dias diferentes', () {
      final List<TimeWindow> compact = compactAllowedHours(expandAllowedHours(hours));
      expect(compact, hasLength(3));
      expect(compact.first.days, <int>[1, 2, 3, 4, 5]);
      expect(expandAllowedHours(AllowedHours(enabled: true, windows: compact))[6], hasLength(2));
    });

    test('adicionar, remover e copiar', () {
      WeekWindows week = expandAllowedHours(hours);
      const DayWindow sunday = DayWindow(LocalTime(10, 0), LocalTime(18, 0));
      week = addDayWindow(week, 7, sunday);
      week = addDayWindow(week, 7, sunday);
      expect(week[7], <DayWindow>[sunday]);
      week = removeDayWindow(week, 7, sunday);
      expect(week[7], isEmpty);
      week = copyDayWindows(week, from: 1, to: const <int>[6, 7]);
      expect(week[7], week[1]);
      expect(blockedDays(week), isEmpty);
    });

    test('janela precisa terminar depois de comecar', () {
      expect(validateDayWindow(const LocalTime(8, 0), const LocalTime(8, 0)), isNotNull);
      expect(validateDayWindow(const LocalTime(21, 0), const LocalTime(7, 0)), isNotNull);
      expect(validateDayWindow(const LocalTime(8, 0), LocalTime.endOfDay), isNull);
    });
  });

  group('resumos', () {
    test('dias da semana', () {
      expect(describeDays(const <int>[1, 2, 3, 4, 5, 6, 7]), 'todos os dias');
      expect(describeDays(const <int>[1, 2, 3, 4, 5]), 'seg a sex');
      expect(describeDays(const <int>[7, 6]), 'sáb e dom');
      expect(describeDays(const <int>[1, 3, 5]), 'seg, qua e sex');
      expect(describeDays(const <int>[]), 'nenhum dia');
    });

    test('limite diario', () {
      expect(dailyLimitSummary(DailyLimit.disabled), 'Desligado');
      expect(dailyLimitSummary(const DailyLimit(enabled: true, minutes: 150)), '2h 30min por dia');
      expect(
        dailyLimitSummary(
          const DailyLimit(enabled: true, minutes: 150, perWeekday: <int, int>{6: 240, 7: 240}),
        ),
        '2h 30min por dia (sáb e dom: 4h)',
      );
      expect(
        dailyLimitSummary(
          const DailyLimit(enabled: true, minutes: 375, perWeekday: <int, int>{1: 375}),
        ),
        '6h 15min por dia',
      );
    });

    test('horarios e periodos', () {
      expect(allowedHoursSummary(AllowedHours.disabled), 'Sem restrição de horário');
      expect(
        allowedHoursSummary(
          const AllowedHours(
            enabled: true,
            windows: <TimeWindow>[
              TimeWindow(
                days: <int>[1, 2, 3, 4, 5, 6, 7],
                start: LocalTime(7, 0),
                end: LocalTime(21, 0),
              ),
            ],
          ),
        ),
        'Todos os dias, 07:00 às 21:00',
      );
      const BlockPeriod bedtime = BlockPeriod.weekly(
        id: 'p1',
        label: 'Hora de dormir',
        days: <int>[1, 2, 3, 4, 5, 6, 7],
        start: LocalTime(21, 0),
        end: LocalTime(7, 0),
      );
      expect(describeBlockPeriod(bedtime), 'Todos os dias, 21:00 às 07:00 do dia seguinte');
      expect(blockPeriodsSummary(const <BlockPeriod>[]), 'Nenhum período');
      expect(blockPeriodsSummary(const <BlockPeriod>[bedtime]), '1 ativo: Hora de dormir');
      expect(
        blockPeriodsSummary(<BlockPeriod>[bedtime.withEnabled(false)]),
        '1 período desativado',
      );
    });

    test('apps, web e protecao', () {
      const AppsPolicy apps = AppsPolicy(
        rules: <String, AppRule>{
          'a': AppRule(state: AppRuleState.blocked),
          'b': AppRule(state: AppRuleState.exception),
          'c': AppRule(state: AppRuleState.allowed, dailyLimitMinutes: 30),
        },
      );
      expect(appsSummary(apps), '1 bloqueado, 1 exceção, 1 com limite próprio');
      expect(appsSummary(const AppsPolicy()), 'Nenhuma regra por app');
      expect(exceptionsSummary(apps), 'Emergência, sistema e 1 app liberado');
      expect(webSummary(const WebPolicy(managedBrowser: false)), 'Navegador gerenciado desligado');
      expect(
        webSummary(const WebPolicy(mode: WebMode.allowlist, allowedDomains: <String>['a.com'])),
        'Só sites autorizados (1)',
      );
      expect(webSummary(const WebPolicy()), 'Bloqueia: 2 categorias, filtro familiar');
      expect(
        protectionSummary(const ProtectionPolicy(), DeviceManagementMode.standard),
        'Só avisa se a proteção for desativada',
      );
      expect(
        protectionSummary(const ProtectionPolicy(), DeviceManagementMode.deviceOwner),
        contains('5 de 7 travas'),
      );
    });
  });

  test('identificador gerado tem o formato UUID versao 4', () {
    final RegExp pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(pattern.hasMatch(newUuid()), isTrue);
    expect(newUuid(), isNot(newUuid()));
  });

  group('AppEntry', () {
    test('le o inventario e ordena os mais usados do dia', () {
      final DeviceApps apps = DeviceApps.fromJson(
        decodeJsonObject(
          '{"day":"2026-11-17","apps":['
          '{"package":"com.a","label":"A","category":"games","todayMs":10},'
          '{"package":"com.b","label":"","category":"desconhecida","todayMs":30,"system":true,'
          '"launchable":false,"essential":true},'
          '{"package":"com.c","label":"C","category":"video","todayMs":0}]}',
        ),
      );
      expect(apps.apps[0].category, AppCategory.games);
      expect(apps.apps[1].label, 'com.b');
      expect(apps.apps[1].category, AppCategory.other);
      expect(apps.apps[1].isUserFacing, isFalse);
      expect(apps.apps[0].isUserFacing, isTrue);
      expect(apps.topToday().map((AppEntry app) => app.package), <String>['com.b', 'com.a']);
    });
  });
}
