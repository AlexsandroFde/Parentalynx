import '../../../../core/time/formatters.dart';
import '../../domain/entities/report_period.dart';

/// Textos dos periodos de relatorio.
extension ReportPeriodText on ReportPeriod {
  /// Descricao do intervalo: `ter 17/11` ou `11/11 a 17/11`.
  String get rangeLabel {
    if (isSingleDay) {
      return formatDayLabel(from);
    }
    return '${formatShortDate(parseDay(from))} a ${formatShortDate(parseDay(to))}';
  }
}
