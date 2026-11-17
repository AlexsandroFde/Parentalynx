import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/features/guardian/apps/domain/app_entry.dart';
import 'package:parentalynx/features/guardian/reports/domain/event_texts.dart';
import 'package:parentalynx/features/guardian/reports/domain/report_models.dart';
import 'package:parentalynx/features/guardian/reports/domain/report_period.dart';

import '../dashboard/support/guardian_fixtures.dart';

void main() {
  group('ReportPeriod', () {
    const String today = '2026-11-17';

    test('atalhos partem do dia da cota do aparelho', () {
      expect(ReportPeriod.preset(ReportPreset.today, today: today).from, today);
      final ReportPeriod yesterday = ReportPeriod.preset(ReportPreset.yesterday, today: today);
      expect(yesterday.from, '2026-11-16');
      expect(yesterday.isSingleDay, isTrue);
      final ReportPeriod week = ReportPeriod.preset(ReportPreset.last7, today: today);
      expect(week.from, '2026-11-11');
      expect(week.days, 7);
      expect(week.rangeLabel, '11/11 a 17/11');
      final ReportPeriod month = ReportPeriod.preset(ReportPreset.last30, today: today);
      expect(month.from, '2026-10-19');
      expect(month.days, 30);
    });

    test('personalizado ordena, nao passa de hoje e respeita o maximo de dias', () {
      final ReportPeriod swapped = ReportPeriod.custom('2026-11-10', '2026-11-01', today: today);
      expect(swapped.from, '2026-11-01');
      expect(swapped.to, '2026-11-10');
      final ReportPeriod future = ReportPeriod.custom('2026-11-15', '2026-12-01', today: today);
      expect(future.to, today);
      final ReportPeriod long = ReportPeriod.custom('2026-01-01', today, today: today);
      expect(long.days, ReportPeriod.maxDays);
      expect(long.to, today);
    });
  });

  group('eixo de duracao', () {
    test('marcas redondas com cerca de quatro intervalos', () {
      expect(durationAxis(0), (interval: 5.0, max: 5.0));
      expect(durationAxis(50), (interval: 15.0, max: 60.0));
      expect(durationAxis(150), (interval: 60.0, max: 180.0));
      expect(durationAxis(240), (interval: 60.0, max: 240.0));
      expect(durationAxis(400), (interval: 120.0, max: 480.0));
      expect(durationTick(0), '0');
      expect(durationTick(90), '1h 30min');
    });
  });

  group('ReportSummary', () {
    final ReportSummary summary = ReportSummary.fromJson(
      decodeJsonObject(jsonEncode(summaryJson())),
    );

    test('le totais, dias, apps, categorias e horas', () {
      expect(summary.totals.totalMs, 880 * 60000);
      expect(summary.daily, hasLength(7));
      expect(summary.daily[3].totalMs, 0);
      expect(summary.daily[0].outsideQuotaMs, 20 * 60000);
      expect(summary.apps.first.label, 'YouTube');
      expect(summary.apps.first.category, AppCategory.video);
      expect(summary.categories, hasLength(5));
      expect(summary.hourly, hasLength(24));
      expect(summary.peakHour, 19);
      expect(summary.blockedByApp.first.count, 9);
      expect(summary.hasUsage, isTrue);
    });

    test('resposta minima nao quebra e completa as 24 horas', () {
      final ReportSummary empty = ReportSummary.fromJson(
        decodeJsonObject('{"from":"2026-11-17","to":"2026-11-17","hourly":[1,2]}'),
      );
      expect(empty.hourly, hasLength(24));
      expect(empty.totals.totalMs, 0);
      expect(empty.hasUsage, isFalse);
      expect(empty.daily, isEmpty);
    });
  });

  group('linha do tempo', () {
    UsageSession session(int startMin, int endMin) {
      return UsageSession(
        package: 'com.a',
        label: 'A',
        category: AppCategory.games,
        start: startMin * 60000,
        end: endMin * 60000,
        durationMs: (endMin - startMin) * 60000,
        tzOffsetMin: -180,
      );
    }

    test('ordena as sessoes e marca as pausas longas', () {
      final List<Object> items = buildTimeline(<UsageSession>[
        session(100, 130),
        session(0, 20),
        session(25, 40),
      ]);
      expect(items.whereType<UsageSession>(), hasLength(3));
      final List<InactivityGap> gaps = items.whereType<InactivityGap>().toList();
      expect(gaps, hasLength(1));
      expect(gaps.single.durationMs, 60 * 60000);
      expect(items[2], isA<InactivityGap>());
    });

    test('horario local usa o deslocamento de fuso da sessao', () {
      final UsageSession item = session(600, 630);
      expect(item.localStart.hour, 7);
      expect(item.localStart.minute, 0);
    });
  });

  group('textos de eventos', () {
    DeviceEvent event(String type, Map<String, Object?> data, {String? label}) {
      return DeviceEvent(id: 1, type: type, ts: 0, data: JsonMap(data), label: label);
    }

    test('tentativa bloqueada traz o app e o motivo', () {
      final ({String title, String? detail}) text = describeEvent(
        event('blocked_attempt', <String, Object?>{'reason': 'daily_limit'}, label: 'TikTok'),
      );
      expect(text.title, 'Tentou abrir TikTok');
      expect(text.detail, 'Motivo: limite diário atingido.');
    });

    test('permissao revogada e pedido de tempo', () {
      expect(
        describeEvent(
          event('permission_changed', <String, Object?>{
            'permission': 'accessibility',
            'granted': false,
          }),
        ).title,
        'Serviço de acessibilidade: revogada',
      );
      expect(
        describeEvent(event('time_request', <String, Object?>{'minutes': 30})).title,
        'Pediu mais 30min',
      );
    });

    test('grupos de filtro e motivos de navegacao', () {
      expect(EventGroup.of('blocked_attempt'), EventGroup.blocks);
      expect(EventGroup.of('clock_changed'), EventGroup.security);
      expect(EventGroup.of('tipo_novo'), EventGroup.system);
      expect(browsingReasonLabel('safe_dns'), 'Filtro DNS familiar');
      expect(browsingReasonLabel(null), 'Bloqueado');
    });
  });
}
