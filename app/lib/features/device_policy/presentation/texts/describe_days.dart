import '../../../../core/time/formatters.dart';

/// Descreve um conjunto de dias da semana ISO: `todos os dias`, `seg a sex`, `sáb e dom`,
/// `seg, qua e sex`.
///
/// Usado nos resumos de todas as funcionalidades de regras.
String describeDays(Iterable<int> days) {
  final List<int> sorted = days.toSet().toList()..sort();
  if (sorted.isEmpty) {
    return 'nenhum dia';
  }
  if (sorted.length == 7) {
    return 'todos os dias';
  }
  final bool consecutive = sorted.last - sorted.first == sorted.length - 1;
  if (consecutive && sorted.length >= 3) {
    return '${weekdayShort(sorted.first)} a ${weekdayShort(sorted.last)}';
  }
  final List<String> names = sorted.map(weekdayShort).toList();
  if (names.length == 1) {
    return names.single;
  }
  return '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
}

/// Primeira letra maiuscula: `todos os dias` vira `Todos os dias`.
String capitalizeFirst(String text) {
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}
