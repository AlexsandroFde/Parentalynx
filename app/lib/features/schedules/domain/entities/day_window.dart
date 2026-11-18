import 'package:equatable/equatable.dart';

import '../../../device_policy/domain/entities/policy.dart';

/// Janela de uso permitido em um unico dia.
///
/// A politica guarda janelas que valem para varios dias (`TimeWindow`); a tela edita dia a
/// dia. As funcoes de `allowed_hours_editing.dart` convertem entre as duas formas.
final class DayWindow extends Equatable implements Comparable<DayWindow> {
  const DayWindow(this.start, this.end);

  final LocalTime start;
  final LocalTime end;

  @override
  int compareTo(DayWindow other) {
    final int byStart = start.compareTo(other.start);
    return byStart != 0 ? byStart : end.compareTo(other.end);
  }

  @override
  List<Object?> get props => <Object?>[start, end];

  @override
  String toString() => '$start às $end';
}

/// Janelas por dia da semana ISO (1 = segunda). Todo dia de 1 a 7 esta presente. Lista vazia
/// significa dia bloqueado o dia inteiro.
typedef WeekWindows = Map<int, List<DayWindow>>;
