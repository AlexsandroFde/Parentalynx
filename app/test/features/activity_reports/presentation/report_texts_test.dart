import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/device_event.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/report_period.dart';
import 'package:parentalynx/features/activity_reports/presentation/texts/event_texts.dart';
import 'package:parentalynx/features/activity_reports/presentation/texts/report_texts.dart';
import 'package:parentalynx/features/activity_reports/presentation/widgets/chart_scale.dart';

void main() {
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

  test('descricao do periodo', () {
    expect(
      ReportPeriod.preset(ReportPreset.last7, today: '2026-11-17').rangeLabel,
      '11/11 a 17/11',
    );
    expect(ReportPeriod.preset(ReportPreset.today, today: '2026-11-17').rangeLabel, 'ter 17/11');
  });

  group('textos de eventos', () {
    DeviceEvent event(String type, EventDetails details, {String? label}) {
      return DeviceEvent(id: 1, type: type, ts: 0, details: details, label: label);
    }

    test('tentativa bloqueada traz o app e o motivo', () {
      final ({String title, String? detail}) text = describeEvent(
        event('blocked_attempt', const EventDetails(reason: 'daily_limit'), label: 'TikTok'),
      );
      expect(text.title, 'Tentou abrir TikTok');
      expect(text.detail, 'Motivo: limite diário atingido.');
    });

    test('permissao revogada e pedido de tempo', () {
      expect(
        describeEvent(
          event(
            'permission_changed',
            const EventDetails(permission: 'accessibility', granted: false),
          ),
        ).title,
        'Serviço de acessibilidade: revogada',
      );
      expect(
        describeEvent(event('time_request', const EventDetails(minutes: 30))).title,
        'Pediu mais 30min',
      );
    });

    test('permissao sem o campo granted conta como revogada', () {
      expect(
        describeEvent(event('permission_changed', EventDetails.none)).detail,
        'O controle pode ficar degradado.',
      );
    });

    test('motivos de navegacao', () {
      expect(browsingReasonLabel('safe_dns'), 'Filtro DNS familiar');
      expect(browsingReasonLabel(null), 'Bloqueado');
    });
  });
}
