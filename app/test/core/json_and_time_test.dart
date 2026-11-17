import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/time/formatters.dart';

void main() {
  group('JsonMap', () {
    final JsonMap json = decodeJsonObject(
      '{"nome":"João","idade":9,"nota":7.0,"ativo":true,"filho":{"x":1},'
      '"lista":[{"a":1},{"a":2}],"textos":["a","b"],"numeros":[1,2.0],"nulo":null}',
    );

    test('le campos tipados', () {
      expect(json.str('nome'), 'João');
      expect(json.integer('idade'), 9);
      expect(json.integer('nota'), 7);
      expect(json.boolean('ativo'), isTrue);
      expect(json.obj('filho').integer('x'), 1);
      expect(json.objList('lista').map((JsonMap item) => item.integer('a')), <int>[1, 2]);
      expect(json.strList('textos'), <String>['a', 'b']);
      expect(json.intList('numeros'), <int>[1, 2]);
    });

    test('campo ausente ou nulo', () {
      expect(json.strOrNull('nulo'), isNull);
      expect(json.intOrNull('faltando'), isNull);
      expect(json.has('nulo'), isFalse);
      expect(json.objList('faltando'), isEmpty);
      expect(json.intOr('faltando', fallback: 3), 3);
      expect(json.boolOr('faltando', fallback: true), isTrue);
      expect(() => json.str('faltando'), throwsA(isA<JsonFormatException>()));
    });

    test('tipo errado lanca erro de formato', () {
      expect(() => json.str('idade'), throwsA(isA<JsonFormatException>()));
      expect(() => json.integer('nome'), throwsA(isA<JsonFormatException>()));
      expect(() => json.obj('nome'), throwsA(isA<JsonFormatException>()));
      expect(() => json.strList('numeros'), throwsA(isA<JsonFormatException>()));
    });

    test('recusa JSON que nao e objeto ou e invalido', () {
      expect(() => decodeJsonObject('[1,2]'), throwsA(isA<JsonFormatException>()));
      expect(() => decodeJsonObject('{nao e json'), throwsA(isA<JsonFormatException>()));
    });
  });

  group('formatacao de duracao', () {
    test('minutos e horas', () {
      expect(formatMinutes(0), '0min');
      expect(formatMinutes(45), '45min');
      expect(formatMinutes(60), '1h');
      expect(formatMinutes(150), '2h 30min');
      expect(formatMinutes(375), '6h 15min');
    });

    test('milissegundos', () {
      expect(formatDurationMs(0), '0min');
      expect(formatDurationMs(-5), '0min');
      expect(formatDurationMs(30000), 'menos de 1min');
      expect(formatDurationMs(9000000), '2h 30min');
    });

    test('contagem regressiva', () {
      expect(formatCountdown(0), '00:00');
      expect(formatCountdown(309000), '05:09');
      expect(formatCountdown(3909000), '1:05:09');
    });
  });

  group('formatacao de data e hora', () {
    final DateTime now = DateTime(2026, 11, 17, 15, 30);

    test('relativa', () {
      expect(formatRelative(now.subtract(const Duration(seconds: 20)), now: now), 'agora');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), 'há 5 min');
      expect(formatRelative(now.subtract(const Duration(hours: 2)), now: now), 'há 2 h');
      expect(formatRelative(DateTime(2026, 11, 16, 14, 30), now: now), 'ontem às 14:30');
      expect(formatRelative(DateTime(2026, 11, 12, 9), now: now), '12/11 às 09:00');
      expect(formatRelative(DateTime(2025, 12, 31, 9), now: now), '31/12/2025 às 09:00');
    });

    test('horario de liberacao', () {
      final int today = DateTime(2026, 11, 17, 21).millisecondsSinceEpoch;
      final int tomorrow = DateTime(2026, 11, 18, 7).millisecondsSinceEpoch;
      final int later = DateTime(2026, 11, 20, 7).millisecondsSinceEpoch;
      expect(formatReleaseTime(today, now: now), 'às 21:00');
      expect(formatReleaseTime(tomorrow, now: now), 'amanhã às 07:00');
      expect(formatReleaseTime(later, now: now), '20/11 às 07:00');
    });
  });

  group('dias da cota', () {
    test('soma, diferenca e dia da semana', () {
      expect(addDays('2026-11-17', -1), '2026-11-16');
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2026-03-01', -1), '2026-02-28');
      expect(daysBetweenInclusive('2026-11-11', '2026-11-17'), 7);
      // 17 de novembro de 2026 e uma terca-feira.
      expect(weekdayOfDay('2026-11-17'), 2);
    });

    test('rotulos', () {
      expect(formatDayLabel('2026-11-17'), 'ter 17/11');
      expect(formatDayRelative('2026-11-17', today: '2026-11-17'), 'Hoje');
      expect(formatDayRelative('2026-11-16', today: '2026-11-17'), 'Ontem');
      expect(formatDayRelative('2026-11-14', today: '2026-11-17'), 'sáb 14/11');
      expect(weekdayLong(7), 'domingo');
    });

    test('recusa dia mal formado', () {
      expect(() => parseDay('17/11/2026'), throwsFormatException);
    });
  });
}
