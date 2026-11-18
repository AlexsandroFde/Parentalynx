/// Horario local `HH:mm`. Em fim de janela aceita `24:00`.
class LocalTime implements Comparable<LocalTime> {
  const LocalTime(this.hour, this.minute);

  /// Le `HH:mm`. Lanca [FormatException] quando o texto nao e um horario valido.
  factory LocalTime.parse(String text) {
    final List<String> parts = text.split(':');
    if (parts.length != 2) {
      throw FormatException('Horario invalido: $text');
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || minute < 0 || minute > 59) {
      throw FormatException('Horario invalido: $text');
    }
    if (hour > 24 || (hour == 24 && minute != 0)) {
      throw FormatException('Horario invalido: $text');
    }
    return LocalTime(hour, minute);
  }

  factory LocalTime.fromMinutes(int minutesOfDay) {
    return LocalTime(minutesOfDay ~/ 60, minutesOfDay % 60);
  }

  static const LocalTime midnight = LocalTime(0, 0);
  static const LocalTime endOfDay = LocalTime(24, 0);

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  @override
  int compareTo(LocalTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) => other is LocalTime && other.minutesOfDay == minutesOfDay;

  @override
  int get hashCode => minutesOfDay.hashCode;

  /// Forma `HH:mm`, a mesma do protocolo.
  @override
  String toString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
