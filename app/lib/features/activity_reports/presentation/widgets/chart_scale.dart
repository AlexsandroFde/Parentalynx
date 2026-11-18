import '../../../../core/time/formatters.dart';

/// Escala do eixo de duracoes de um grafico: intervalo entre marcas e topo, em minutos.
///
/// As marcas caem em valores redondos (15min, 30min, 1h, 2h, 4h), com no maximo cerca de
/// cinco linhas.
({double interval, double max}) durationAxis(double maxMinutes) {
  const List<double> steps = <double>[5, 10, 15, 30, 60, 120, 240, 480];
  double interval = steps.last;
  for (final double step in steps) {
    if (maxMinutes / step <= 4) {
      interval = step;
      break;
    }
  }
  final double top = maxMinutes <= 0 ? interval : (maxMinutes / interval).ceil() * interval;
  return (interval: interval, max: top);
}

/// Rotulo de uma marca do eixo de duracoes: `0`, `30min`, `1h`, `1h 30min`.
String durationTick(double minutes) {
  final int value = minutes.round();
  return value == 0 ? '0' : formatMinutes(value);
}
