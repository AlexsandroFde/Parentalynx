import 'package:equatable/equatable.dart';

import 'local_time.dart';

/// Limite diario de uso (protocolo, secao 4.2, `dailyLimit`).
final class DailyLimit extends Equatable {
  const DailyLimit({
    required this.enabled,
    required this.minutes,
    this.perWeekday = const <int, int>{},
    this.resetTime = LocalTime.midnight,
    this.warnAtMinutes = const <int>[15, 5],
  });

  static const DailyLimit disabled = DailyLimit(enabled: false, minutes: 120);

  /// Minutos padrao quando a politica nao informa.
  static const int defaultMinutes = 120;

  /// Avisos padrao para a crianca, em minutos restantes.
  static const List<int> defaultWarnings = <int>[15, 5];

  final bool enabled;

  /// Minutos por dia, de 0 a 1440.
  final int minutes;

  /// Sobreposicao por dia da semana ISO (1 = segunda).
  final Map<int, int> perWeekday;
  final LocalTime resetTime;
  final List<int> warnAtMinutes;

  /// Limite do dia da semana informado, sem tempo extra.
  int minutesFor(int isoWeekday) => perWeekday[isoWeekday] ?? minutes;

  bool get sameEveryDay => perWeekday.isEmpty;

  /// Liga ou desliga o limite por dia da semana. Ao ligar, cada dia comeca com o valor que
  /// vale hoje para ele; ao desligar, todos voltam ao valor padrao.
  DailyLimit withPerWeekday(bool value) {
    if (!value) {
      return copyWith(perWeekday: const <int, int>{});
    }
    return copyWith(
      perWeekday: <int, int>{for (int day = 1; day <= 7; day++) day: minutesFor(day)},
    );
  }

  /// Troca o limite de um dia da semana.
  DailyLimit withDayMinutes(int isoWeekday, int value) {
    return copyWith(perWeekday: <int, int>{...perWeekday, isoWeekday: value});
  }

  DailyLimit copyWith({
    bool? enabled,
    int? minutes,
    Map<int, int>? perWeekday,
    LocalTime? resetTime,
    List<int>? warnAtMinutes,
  }) {
    return DailyLimit(
      enabled: enabled ?? this.enabled,
      minutes: minutes ?? this.minutes,
      perWeekday: perWeekday ?? this.perWeekday,
      resetTime: resetTime ?? this.resetTime,
      warnAtMinutes: warnAtMinutes ?? this.warnAtMinutes,
    );
  }

  @override
  List<Object?> get props => <Object?>[enabled, minutes, perWeekday, resetTime, warnAtMinutes];
}
