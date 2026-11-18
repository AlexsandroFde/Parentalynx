import 'package:equatable/equatable.dart';

import 'local_time.dart';

/// Janela de uso permitido em alguns dias da semana.
final class TimeWindow extends Equatable {
  const TimeWindow({required this.days, required this.start, required this.end});

  /// Dias da semana ISO (1 = segunda) em que a janela vale.
  final List<int> days;
  final LocalTime start;
  final LocalTime end;

  TimeWindow copyWith({List<int>? days, LocalTime? start, LocalTime? end}) {
    return TimeWindow(days: days ?? this.days, start: start ?? this.start, end: end ?? this.end);
  }

  @override
  List<Object?> get props => <Object?>[days, start, end];
}

/// Horarios em que o uso e permitido (protocolo, secao 4.2, `allowedHours`).
final class AllowedHours extends Equatable {
  const AllowedHours({required this.enabled, this.windows = const <TimeWindow>[]});

  static const AllowedHours disabled = AllowedHours(enabled: false);

  final bool enabled;
  final List<TimeWindow> windows;

  /// Janelas que valem para o dia da semana informado.
  List<TimeWindow> windowsFor(int isoWeekday) {
    return windows.where((TimeWindow window) => window.days.contains(isoWeekday)).toList();
  }

  AllowedHours copyWith({bool? enabled, List<TimeWindow>? windows}) {
    return AllowedHours(enabled: enabled ?? this.enabled, windows: windows ?? this.windows);
  }

  @override
  List<Object?> get props => <Object?>[enabled, windows];
}

enum BlockPeriodKind { weekly, once }

/// Periodo de bloqueio recorrente (semanal) ou pontual.
final class BlockPeriod extends Equatable {
  const BlockPeriod.weekly({
    required this.id,
    required this.label,
    required this.days,
    required LocalTime this.start,
    required LocalTime this.end,
    this.enabled = true,
  }) : kind = BlockPeriodKind.weekly,
       startAt = null,
       endAt = null;

  const BlockPeriod.once({
    required this.id,
    required this.label,
    required int this.startAt,
    required int this.endAt,
    this.enabled = true,
  }) : kind = BlockPeriodKind.once,
       days = const <int>[],
       start = null,
       end = null;

  final String id;
  final String label;
  final bool enabled;
  final BlockPeriodKind kind;

  /// Dias em que o periodo semanal comeca.
  final List<int> days;
  final LocalTime? start;
  final LocalTime? end;
  final int? startAt;
  final int? endAt;

  /// Verdadeiro quando o periodo semanal atravessa a meia-noite.
  bool get crossesMidnight {
    final LocalTime? startTime = start;
    final LocalTime? endTime = end;
    return startTime != null && endTime != null && startTime.compareTo(endTime) > 0;
  }

  BlockPeriod withEnabled(bool value) {
    return switch (kind) {
      BlockPeriodKind.weekly => BlockPeriod.weekly(
        id: id,
        label: label,
        days: days,
        start: start!,
        end: end!,
        enabled: value,
      ),
      BlockPeriodKind.once => BlockPeriod.once(
        id: id,
        label: label,
        startAt: startAt!,
        endAt: endAt!,
        enabled: value,
      ),
    };
  }

  @override
  List<Object?> get props => <Object?>[id, label, enabled, kind, days, start, end, startAt, endAt];
}
