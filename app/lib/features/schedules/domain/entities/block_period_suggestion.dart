import '../../../device_policy/domain/entities/policy.dart';

/// Periodos de bloqueio sugeridos quando ainda nao ha nenhum.
enum BlockPeriodSuggestion {
  bedtime('Hora de dormir', <int>[1, 2, 3, 4, 5, 6, 7], LocalTime(21, 0), LocalTime(7, 0)),
  school('Escola', <int>[1, 2, 3, 4, 5], LocalTime(7, 0), LocalTime(12, 0));

  const BlockPeriodSuggestion(this.label, this.days, this.start, this.end);

  final String label;
  final List<int> days;
  final LocalTime start;
  final LocalTime end;

  /// Periodo semanal da sugestao com o identificador informado.
  BlockPeriod toPeriod(String id) {
    return BlockPeriod.weekly(id: id, label: label, days: days, start: start, end: end);
  }
}
