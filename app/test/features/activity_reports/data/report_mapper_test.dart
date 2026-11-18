import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/features/activity_reports/data/dto/report_dtos.dart';
import 'package:parentalynx/features/activity_reports/data/mappers/report_mapper.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/browsing_entry.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/device_event.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/report_summary.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/usage_session.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_entry.dart';

import '../../../support/guardian_api_fixtures.dart';

ReportSummary _summaryOf(String source) {
  return ReportMapper.summary(ReportSummaryDto.fromJson(decodeJsonObject(source)));
}

void main() {
  group('resumo do relatorio', () {
    final ReportSummary summary = _summaryOf(jsonEncode(summaryJson()));

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
      expect(summary.isMultiDay, isTrue);
      expect(summary.percentOfTotal(440 * 60000), 50);
    });

    test('resposta minima nao quebra e completa as 24 horas', () {
      final ReportSummary empty = _summaryOf(
        '{"from":"2026-11-17","to":"2026-11-17","hourly":[1,2]}',
      );
      expect(empty.hourly, hasLength(24));
      expect(empty.hourly.take(3), <int>[1, 2, 0]);
      expect(empty.totals.totalMs, 0);
      expect(empty.hasUsage, isFalse);
      expect(empty.daily, isEmpty);
      expect(empty.timezone, 'UTC');
      expect(empty.percentOfTotal(10), isNull);
    });
  });

  test('sessao sem fim nem duracao usa o inicio', () {
    final UsageSession session = ReportMapper.session(
      UsageSessionDto.fromJson(
        const JsonMap(<String, Object?>{'package': 'com.a', 'start': 1000, 'category': 'nova'}),
      ),
    );
    expect(session.label, 'com.a');
    expect(session.end, 1000);
    expect(session.durationMs, 0);
    expect(session.category, AppCategory.other);
  });

  test('evento le os detalhes conhecidos e ignora valores de tipo inesperado', () {
    final DeviceEvent event = ReportMapper.event(
      DeviceEventDto.fromJson(
        const JsonMap(<String, Object?>{
          'id': 7,
          'type': 'permission_changed',
          'ts': 5,
          'data': <String, Object?>{
            'permission': 'accessibility',
            'granted': false,
            'reason': 42,
            'minutes': 30.0,
          },
        }),
      ),
    );
    expect(event.details.permission, 'accessibility');
    expect(event.details.granted, isFalse);
    expect(event.details.reason, isNull);
    expect(event.details.minutes, 30);
    expect(event.appName, 'app');
  });

  test('pagina de navegacao aceita cursor numerico ou em texto', () {
    final CursorPageDto<BrowsingEntryDto> numeric = CursorPageDto<BrowsingEntryDto>.fromJson(
      const JsonMap(<String, Object?>{
        'entries': <Object?>[
          <String, Object?>{'id': 3, 'url': 'https://a.com', 'domain': 'a.com'},
        ],
        'nextBefore': 3,
      }),
      'entries',
      BrowsingEntryDto.fromJson,
    );
    expect(numeric.nextBefore, '3');
    final BrowsingEntry entry = ReportMapper.browsing(numeric.items.single);
    expect(entry.id, '3');
    expect(entry.displayTitle, 'a.com');
    expect(entry.blocked, isFalse);
  });
}
