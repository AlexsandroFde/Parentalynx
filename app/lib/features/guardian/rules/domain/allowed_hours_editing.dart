import '../../../../shared/domain/policy.dart';

/// Edicao dos horarios permitidos por dia da semana.
///
/// A politica guarda janelas que valem para varios dias (`TimeWindow`). A tela edita dia a
/// dia. Estas funcoes puras convertem entre as duas formas.

/// Janela de uso em um unico dia.
class DayWindow implements Comparable<DayWindow> {
  const DayWindow(this.start, this.end);

  final LocalTime start;
  final LocalTime end;

  @override
  int compareTo(DayWindow other) {
    final int byStart = start.compareTo(other.start);
    return byStart != 0 ? byStart : end.compareTo(other.end);
  }

  @override
  bool operator ==(Object other) {
    return other is DayWindow && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start às $end';
}

/// Janelas por dia da semana ISO (1 = segunda). Todo dia de 1 a 7 esta presente. Lista vazia
/// significa dia bloqueado o dia inteiro.
typedef WeekWindows = Map<int, List<DayWindow>>;

/// Abre as janelas da politica em uma lista por dia da semana, em ordem de inicio.
WeekWindows expandAllowedHours(AllowedHours hours) {
  final WeekWindows byDay = <int, List<DayWindow>>{
    for (int day = 1; day <= 7; day++) day: <DayWindow>[],
  };
  for (final TimeWindow window in hours.windows) {
    for (final int day in window.days) {
      final List<DayWindow>? list = byDay[day];
      final DayWindow item = DayWindow(window.start, window.end);
      if (list != null && !list.contains(item)) {
        list.add(item);
      }
    }
  }
  for (final List<DayWindow> list in byDay.values) {
    list.sort();
  }
  return byDay;
}

/// Junta as janelas iguais de dias diferentes em uma so, para gravar na politica.
List<TimeWindow> compactAllowedHours(WeekWindows byDay) {
  final Map<DayWindow, List<int>> daysByWindow = <DayWindow, List<int>>{};
  for (int day = 1; day <= 7; day++) {
    for (final DayWindow window in byDay[day] ?? const <DayWindow>[]) {
      daysByWindow.putIfAbsent(window, () => <int>[]).add(day);
    }
  }
  final List<MapEntry<DayWindow, List<int>>> entries = daysByWindow.entries.toList()
    ..sort((MapEntry<DayWindow, List<int>> a, MapEntry<DayWindow, List<int>> b) {
      final int byFirstDay = a.value.first.compareTo(b.value.first);
      return byFirstDay != 0 ? byFirstDay : a.key.compareTo(b.key);
    });
  return <TimeWindow>[
    for (final MapEntry<DayWindow, List<int>> entry in entries)
      TimeWindow(days: entry.value, start: entry.key.start, end: entry.key.end),
  ];
}

/// Motivo pelo qual a janela nao pode ser gravada, ou nulo se ela e valida.
String? validateDayWindow(LocalTime start, LocalTime end) {
  if (start.compareTo(end) >= 0) {
    return 'O fim precisa ser depois do início, no mesmo dia.';
  }
  return null;
}

/// Devolve a semana com a janela acrescentada ao dia, sem duplicar.
WeekWindows addDayWindow(WeekWindows byDay, int day, DayWindow window) {
  final List<DayWindow> list = <DayWindow>[...byDay[day] ?? const <DayWindow>[]];
  if (!list.contains(window)) {
    list
      ..add(window)
      ..sort();
  }
  return <int, List<DayWindow>>{...byDay, day: list};
}

/// Devolve a semana sem a janela indicada no dia.
WeekWindows removeDayWindow(WeekWindows byDay, int day, DayWindow window) {
  final List<DayWindow> list = <DayWindow>[...byDay[day] ?? const <DayWindow>[]]..remove(window);
  return <int, List<DayWindow>>{...byDay, day: list};
}

/// Copia as janelas de um dia para todos os dias informados.
WeekWindows copyDayWindows(WeekWindows byDay, {required int from, required Iterable<int> to}) {
  final List<DayWindow> source = byDay[from] ?? const <DayWindow>[];
  return <int, List<DayWindow>>{
    ...byDay,
    for (final int day in to) day: <DayWindow>[...source],
  };
}

/// Dias que ficam sem nenhum horario liberado.
List<int> blockedDays(WeekWindows byDay) {
  return <int>[
    for (int day = 1; day <= 7; day++)
      if ((byDay[day] ?? const <DayWindow>[]).isEmpty) day,
  ];
}
