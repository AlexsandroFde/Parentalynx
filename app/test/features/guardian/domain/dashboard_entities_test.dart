import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/guardian/domain/entities/active_commands.dart';
import 'package:parentalynx/features/guardian/domain/entities/device_connection.dart';
import 'package:parentalynx/features/guardian/domain/entities/today_usage.dart';

import '../fixtures/dashboard_entities.dart';

/// Regras do painel que nao dependem da interface.
void main() {
  group('TodayUsage', () {
    test('sem retrato o aparelho ainda nao tem tempo de hoje', () {
      expect(TodayUsage.of(childDeviceOf()), isNull);
    });

    test('usa o restante informado pelo aparelho', () {
      final TodayUsage usage = TodayUsage.of(
        childDeviceOf(
          snapshot: snapshotOf(
            quotaUsedMs: 70 * minuteMs,
            totalUsedMs: 90 * minuteMs,
            limitMs: 150 * minuteMs,
            remainingMs: 80 * minuteMs,
          ),
        ),
      )!;

      expect(usage.stale, isFalse);
      expect(usage.usedMs, 70 * minuteMs);
      expect(usage.totalMs, 90 * minuteMs);
      expect(usage.remainingMs, 80 * minuteMs);
      expect(usage.fraction, closeTo(70 / 150, 0.0001));
      expect(usage.level, QuotaLevel.normal);
      expect(usage.hasLimit, isTrue);
    });

    test('sem restante informado calcula pelo limite e nunca fica negativo', () {
      final TodayUsage partial = TodayUsage.of(
        childDeviceOf(
          snapshot: snapshotOf(quotaUsedMs: 30 * minuteMs, limitMs: 60 * minuteMs),
        ),
      )!;
      final TodayUsage over = TodayUsage.of(
        childDeviceOf(
          snapshot: snapshotOf(quotaUsedMs: 90 * minuteMs, limitMs: 60 * minuteMs),
        ),
      )!;

      expect(partial.remainingMs, 30 * minuteMs);
      expect(over.remainingMs, 0);
      expect(over.fraction, 1);
      expect(over.level, QuotaLevel.exhausted);
    });

    test('retrato de um dia anterior zera o uso e libera o limite inteiro', () {
      final TodayUsage usage = TodayUsage.of(
        childDeviceOf(
          snapshot: snapshotOf(
            day: '2026-11-16',
            quotaUsedMs: 150 * minuteMs,
            limitMs: 150 * minuteMs,
            remainingMs: 0,
            extraMs: 30 * minuteMs,
          ),
        ),
      )!;

      expect(usage.stale, isTrue);
      expect(usage.usedMs, 0);
      expect(usage.totalMs, 0);
      expect(usage.remainingMs, 150 * minuteMs);
      expect(usage.fraction, 0);
      expect(usage.includesExtra, isFalse);
    });

    test('sem limite diario nao ha restante nem consumo da cota', () {
      final TodayUsage usage = TodayUsage.of(
        childDeviceOf(snapshot: snapshotOf(quotaUsedMs: 30 * minuteMs)),
      )!;

      expect(usage.hasLimit, isFalse);
      expect(usage.remainingMs, isNull);
      expect(usage.fraction, 0);
      expect(usage.level, QuotaLevel.normal);
    });

    test('limite zero conta como cota esgotada', () {
      final TodayUsage usage = TodayUsage.of(childDeviceOf(snapshot: snapshotOf(limitMs: 0)))!;

      expect(usage.fraction, 1);
      expect(usage.level, QuotaLevel.exhausted);
    });

    test('tempo extra de hoje aparece como incluido no limite', () {
      final TodayUsage usage = TodayUsage.of(
        childDeviceOf(
          snapshot: snapshotOf(limitMs: 180 * minuteMs, extraMs: 30 * minuteMs),
        ),
      )!;

      expect(usage.includesExtra, isTrue);
    });
  });

  test('QuotaLevel destaca a partir de 80% e quando a cota acaba', () {
    expect(QuotaLevel.of(0.79), QuotaLevel.normal);
    expect(QuotaLevel.of(0.8), QuotaLevel.attention);
    expect(QuotaLevel.of(0.99), QuotaLevel.attention);
    expect(QuotaLevel.of(1), QuotaLevel.exhausted);
  });

  group('ActiveCommands', () {
    test('pausa, suspensao e tempo extra de hoje em vigor', () {
      final ActiveCommands commands = ActiveCommands.of(
        versionedPolicyOf(
          overrides: PolicyOverrides(
            extraTime: const <ExtraTimeGrant>[
              ExtraTimeGrant(id: 'e1', day: dashboardToday, minutes: 30, grantedAt: 1),
              ExtraTimeGrant(id: 'e2', day: dashboardToday, minutes: 15, grantedAt: 2),
              ExtraTimeGrant(id: 'e3', day: '2026-11-16', minutes: 60, grantedAt: 3),
            ],
            manualLock: ManualLock(active: true, until: dashboardNowMs + 60000),
            suspension: Suspension(
              until: dashboardNowMs + 60000,
              scopes: const <SuspensionScope>[SuspensionScope.dailyLimit],
            ),
          ),
        ).policy,
        nowMs: dashboardNowMs,
        today: dashboardToday,
      );

      expect(commands.paused, isTrue);
      expect(commands.suspended, isTrue);
      expect(commands.suspension!.scopes, <SuspensionScope>[SuspensionScope.dailyLimit]);
      expect(commands.extraMinutesToday, 45);
    });

    test('comandos vencidos nao valem mais', () {
      final ActiveCommands commands = ActiveCommands.of(
        versionedPolicyOf(
          overrides: PolicyOverrides(
            manualLock: ManualLock(active: true, until: dashboardNowMs - 1),
            suspension: Suspension(
              until: dashboardNowMs - 1,
              scopes: const <SuspensionScope>[SuspensionScope.appBlocks],
            ),
          ),
        ).policy,
        nowMs: dashboardNowMs,
        today: dashboardToday,
      );

      expect(commands, ActiveCommands.none);
    });

    test('pausa sem prazo vale ate o responsavel retomar', () {
      final ActiveCommands commands = ActiveCommands.of(
        versionedPolicyOf(overrides: const PolicyOverrides(manualLock: ManualLock(active: true)))
            .policy,
        nowMs: dashboardNowMs,
        today: dashboardToday,
      );

      expect(commands.paused, isTrue);
      expect(commands.suspended, isFalse);
    });
  });

  group('DeviceConnection', () {
    test('conectado agora', () {
      expect(
        DeviceConnection.of(childDeviceOf(lastSyncAt: 1), nowMs: dashboardNowMs),
        DeviceConnection.online,
      );
    });

    test('desconectado sem nenhuma sincronizacao', () {
      expect(
        DeviceConnection.of(childDeviceOf(online: false), nowMs: dashboardNowMs),
        DeviceConnection.neverSynced,
      );
    });

    test('desconectado ha pouco e desconectado ha mais de 3 horas', () {
      final int recent = dashboardNowMs - const Duration(hours: 3).inMilliseconds;
      final int stale = recent - 1;

      expect(
        DeviceConnection.of(
          childDeviceOf(online: false, lastSyncAt: recent),
          nowMs: dashboardNowMs,
        ),
        DeviceConnection.recent,
      );
      expect(
        DeviceConnection.of(childDeviceOf(online: false, lastSyncAt: stale), nowMs: dashboardNowMs),
        DeviceConnection.stale,
      );
    });
  });
}
