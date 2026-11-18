part of 'screen_time_bloc.dart';

sealed class ScreenTimeEvent extends Equatable {
  const ScreenTimeEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela de limite diario abriu para um aparelho (ou a pessoa pediu para tentar de novo).
final class ScreenTimeStarted extends ScreenTimeEvent {
  const ScreenTimeStarted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Liga ou desliga o limite diario.
final class DailyLimitEnabledChanged extends ScreenTimeEvent {
  const DailyLimitEnabledChanged(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Troca o tempo por dia (o mesmo em todos os dias).
final class DailyLimitMinutesChanged extends ScreenTimeEvent {
  const DailyLimitMinutesChanged(this.minutes);

  final int minutes;

  @override
  List<Object?> get props => <Object?>[minutes];
}

/// Liga ou desliga o limite diferente por dia da semana.
final class DailyLimitPerWeekdayToggled extends ScreenTimeEvent {
  const DailyLimitPerWeekdayToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Troca o limite de um dia da semana ISO (1 = segunda).
final class DailyLimitWeekdayMinutesChanged extends ScreenTimeEvent {
  const DailyLimitWeekdayMinutesChanged({required this.weekday, required this.minutes});

  final int weekday;
  final int minutes;

  @override
  List<Object?> get props => <Object?>[weekday, minutes];
}

/// Troca o horario de reinicio da contagem.
final class DailyLimitResetTimeChanged extends ScreenTimeEvent {
  const DailyLimitResetTimeChanged(this.resetTime);

  final LocalTime resetTime;

  @override
  List<Object?> get props => <Object?>[resetTime];
}

/// Liga ou desliga um aviso de pouco tempo para a crianca.
final class DailyLimitWarningToggled extends ScreenTimeEvent {
  const DailyLimitWarningToggled({required this.minutes, required this.enabled});

  final int minutes;
  final bool enabled;

  @override
  List<Object?> get props => <Object?>[minutes, enabled];
}

/// Envia o rascunho ao servidor.
final class ScreenTimeSaveRequested extends ScreenTimeEvent {
  const ScreenTimeSaveRequested();
}

/// Descarta as alteracoes locais.
final class ScreenTimeDiscardRequested extends ScreenTimeEvent {
  const ScreenTimeDiscardRequested();
}

/// O servidor informou uma versao nova da politica do aparelho.
final class _ScreenTimeServerVersionChanged extends ScreenTimeEvent {
  const _ScreenTimeServerVersionChanged(this.version);

  final int version;

  @override
  List<Object?> get props => <Object?>[version];
}
