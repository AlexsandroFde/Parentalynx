part of 'activity_reports_bloc.dart';

/// Aparelho, dia da cota e periodo escolhido de um relatorio.
final class ReportQuery extends Equatable {
  const ReportQuery({required this.deviceId, required this.today, required this.selection});

  final String deviceId;

  /// Dia da cota corrente do aparelho.
  final String today;
  final ReportSelection selection;

  ReportPeriod get period => selection.periodFor(today);

  ReportQuery withSelection(ReportSelection value) {
    return ReportQuery(deviceId: deviceId, today: today, selection: value);
  }

  @override
  List<Object?> get props => <Object?>[deviceId, today, selection];
}

/// Relatorio de uso do aparelho em foco.
sealed class ActivityReportsState extends Equatable {
  const ActivityReportsState();

  /// Consulta atual, ou nulo antes de haver aparelho.
  ReportQuery? get query => null;

  /// Relatorio para mostrar: o do periodo atual ou, enquanto ele nao chega, o anterior.
  ReportSummary? get summary => null;

  /// Verdadeiro enquanto um relatorio esta sendo buscado.
  bool get isLoading => false;

  /// Falha da ultima consulta, quando ela falhou.
  AppFailure? get failure => null;

  /// Verdadeiro quando [summary] e do periodo atual.
  bool get isFresh => false;

  @override
  List<Object?> get props => const <Object?>[];
}

/// Ainda nao ha aparelho em foco.
final class ReportsIdle extends ActivityReportsState {
  const ReportsIdle();
}

/// Carregando, sem relatorio anterior para mostrar.
final class ReportsLoading extends ActivityReportsState {
  const ReportsLoading(this.query);

  @override
  final ReportQuery query;

  @override
  bool get isLoading => true;

  @override
  List<Object?> get props => <Object?>[query];
}

/// Relatorio do periodo atual carregado.
final class ReportsLoaded extends ActivityReportsState {
  const ReportsLoaded(this.query, this.summary);

  @override
  final ReportQuery query;

  @override
  final ReportSummary summary;

  @override
  bool get isFresh => true;

  @override
  List<Object?> get props => <Object?>[query, summary];
}

/// Carregando outro periodo: o relatorio anterior continua na tela, esmaecido.
final class ReportsUpdating extends ActivityReportsState {
  const ReportsUpdating(this.query, this.summary);

  @override
  final ReportQuery query;

  /// Relatorio anterior.
  @override
  final ReportSummary summary;

  @override
  bool get isLoading => true;

  @override
  List<Object?> get props => <Object?>[query, summary];
}

/// A consulta falhou e nao ha relatorio para mostrar. A tela oferece tentar de novo.
final class ReportsError extends ActivityReportsState {
  const ReportsError(this.query, this.failure);

  @override
  final ReportQuery query;

  @override
  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[query, failure];
}

/// A consulta falhou: o relatorio anterior continua na tela, esmaecido, com o aviso.
final class ReportsStale extends ActivityReportsState {
  const ReportsStale(this.query, this.summary, this.failure);

  @override
  final ReportQuery query;

  /// Relatorio anterior.
  @override
  final ReportSummary summary;

  @override
  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[query, summary, failure];
}
