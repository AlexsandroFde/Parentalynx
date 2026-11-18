import '../../../../core/result/result.dart';
import '../entities/report_period.dart';
import '../entities/report_summary.dart';
import '../repositories/i_reports_repository.dart';

/// Relatorio de uso de um aparelho no periodo escolhido.
class GetReportSummary {
  const GetReportSummary(this._repository);

  final IReportsRepository _repository;

  Future<Result<ReportSummary>> call(String deviceId, ReportPeriod period) {
    return _repository.summary(deviceId, from: period.from, to: period.to);
  }
}
