/// Tempo em segundo plano depois do qual o painel pede a senha de novo.
enum AppLockTimeout {
  immediately(0, 'Imediatamente'),
  oneMinute(60, '1 minuto'),
  fiveMinutes(300, '5 minutos'),
  fifteenMinutes(900, '15 minutos');

  const AppLockTimeout(this.seconds, this.label);

  final int seconds;
  final String label;

  /// Padrao quando a pessoa nunca escolheu.
  static const AppLockTimeout standard = AppLockTimeout.oneMinute;

  Duration get duration => Duration(seconds: seconds);

  static AppLockTimeout fromSeconds(int seconds) {
    for (final AppLockTimeout option in values) {
      if (option.seconds == seconds) {
        return option;
      }
    }
    return standard;
  }
}
