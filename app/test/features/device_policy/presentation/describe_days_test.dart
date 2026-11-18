import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/device_policy/presentation/texts/describe_days.dart';

void main() {
  group('resumos', () {
    test('dias da semana', () {
      expect(describeDays(const <int>[1, 2, 3, 4, 5, 6, 7]), 'todos os dias');
      expect(describeDays(const <int>[1, 2, 3, 4, 5]), 'seg a sex');
      expect(describeDays(const <int>[7, 6]), 'sáb e dom');
      expect(describeDays(const <int>[1, 3, 5]), 'seg, qua e sex');
      expect(describeDays(const <int>[]), 'nenhum dia');
    });

    test('primeira letra maiuscula', () {
      expect(capitalizeFirst('todos os dias'), 'Todos os dias');
      expect(capitalizeFirst(''), '');
    });
  });
}
