part of 'schedule_bloc.dart';

sealed class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela de horarios abriu para um aparelho (ou a pessoa pediu para tentar de novo).
final class ScheduleStarted extends ScheduleEvent {
  const ScheduleStarted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Liga ou desliga a restricao de horarios de uso.
final class AllowedHoursToggled extends ScheduleEvent {
  const AllowedHoursToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Acrescenta uma janela de uso liberado em um dia da semana ISO.
final class AllowedHoursWindowAdded extends ScheduleEvent {
  const AllowedHoursWindowAdded({required this.weekday, required this.window});

  final int weekday;
  final DayWindow window;

  @override
  List<Object?> get props => <Object?>[weekday, window];
}

/// Remove uma janela de um dia da semana.
final class AllowedHoursWindowRemoved extends ScheduleEvent {
  const AllowedHoursWindowRemoved({required this.weekday, required this.window});

  final int weekday;
  final DayWindow window;

  @override
  List<Object?> get props => <Object?>[weekday, window];
}

/// Copia as janelas de um dia para todos os dias da semana.
final class AllowedHoursDayCopiedToAll extends ScheduleEvent {
  const AllowedHoursDayCopiedToAll(this.weekday);

  final int weekday;

  @override
  List<Object?> get props => <Object?>[weekday];
}

/// Grava um periodo de bloqueio novo ou editado no rascunho.
final class BlockPeriodSaved extends ScheduleEvent {
  const BlockPeriodSaved(this.draft);

  final BlockPeriodDraft draft;

  @override
  List<Object?> get props => <Object?>[draft];
}

/// Exclui um periodo de bloqueio do rascunho.
final class BlockPeriodDeleted extends ScheduleEvent {
  const BlockPeriodDeleted(this.periodId);

  final String periodId;

  @override
  List<Object?> get props => <Object?>[periodId];
}

/// Ativa ou desativa um periodo de bloqueio.
final class BlockPeriodToggled extends ScheduleEvent {
  const BlockPeriodToggled({required this.periodId, required this.enabled});

  final String periodId;
  final bool enabled;

  @override
  List<Object?> get props => <Object?>[periodId, enabled];
}

/// Cria um periodo a partir de uma sugestao.
final class BlockPeriodSuggestionAdded extends ScheduleEvent {
  const BlockPeriodSuggestionAdded(this.suggestion);

  final BlockPeriodSuggestion suggestion;

  @override
  List<Object?> get props => <Object?>[suggestion];
}

/// Envia o rascunho ao servidor.
final class ScheduleSaveRequested extends ScheduleEvent {
  const ScheduleSaveRequested();
}

/// Descarta as alteracoes locais.
final class ScheduleDiscardRequested extends ScheduleEvent {
  const ScheduleDiscardRequested();
}

/// O servidor informou uma versao nova da politica do aparelho.
final class _ScheduleServerVersionChanged extends ScheduleEvent {
  const _ScheduleServerVersionChanged(this.version);

  final int version;

  @override
  List<Object?> get props => <Object?>[version];
}
