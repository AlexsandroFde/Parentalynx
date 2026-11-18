import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/time/clock.dart';
import '../../../domain/entities/report_period.dart';
import '../../../domain/entities/report_summary.dart';
import '../../../domain/usecases/get_report_summary.dart';

part 'activity_reports_event.dart';
part 'activity_reports_state.dart';

/// Relatorio de uso do aparelho em foco, com a escolha de periodo.
///
/// Todas as mudancas (aparelho, periodo, recarga) passam pelo mesmo tratamento com
/// `restartable()`: uma escolha nova cancela a consulta anterior, que ficaria desatualizada.
/// Enquanto o periodo novo carrega, o relatorio anterior continua na tela.
class ActivityReportsBloc extends Bloc<ActivityReportsEvent, ActivityReportsState> {
  ActivityReportsBloc({required this._getReportSummary, required this._clock})
    : super(const ReportsIdle()) {
    on<ActivityReportsEvent>(_onEvent, transformer: restartable());
  }

  final GetReportSummary _getReportSummary;
  final Clock _clock;

  Future<void> _onEvent(ActivityReportsEvent event, Emitter<ActivityReportsState> emit) async {
    final ReportQuery? current = state.query;
    try {
      final ReportQuery? next = switch (event) {
        ReportsDeviceChanged(:final String deviceId, :final String deviceToday) => ReportQuery(
          deviceId: deviceId,
          today: quotaDayOf(deviceToday, _clock.now()),
          selection: current?.selection ?? ReportSelection.initial,
        ),
        ReportsPresetSelected(:final ReportPreset preset) => current?.withSelection(
          ReportSelection(preset: preset),
        ),
        ReportsCustomRangeSelected(:final String from, :final String to) => current?.withSelection(
          ReportSelection(preset: ReportPreset.custom, customFrom: from, customTo: to),
        ),
        ReportsRefreshRequested() => current,
      };
      if (next == null) {
        return;
      }
      await _load(next, emit);
    } finally {
      if (event case ReportsRefreshRequested(:final Completer<void>? completer)) {
        completer?.complete();
      }
    }
  }

  Future<void> _load(ReportQuery query, Emitter<ActivityReportsState> emit) async {
    final ReportSummary? previous = state.summary;
    emit(previous == null ? ReportsLoading(query) : ReportsUpdating(query, previous));
    final Result<ReportSummary> result = await _getReportSummary(query.deviceId, query.period);
    switch (result) {
      case Ok<ReportSummary>(:final ReportSummary value):
        emit(ReportsLoaded(query, value));
      case Err<ReportSummary>(:final AppFailure failure):
        emit(
          previous == null ? ReportsError(query, failure) : ReportsStale(query, previous, failure),
        );
    }
  }
}
