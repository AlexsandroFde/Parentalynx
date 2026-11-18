import '../../../../core/result/result.dart';
import '../entities/day_timeline.dart';
import '../entities/usage_session.dart';
import '../repositories/i_reports_repository.dart';

/// Linha do tempo de um dia: as sessoes de uso em ordem, as pausas longas e o resumo.
class GetDayTimeline {
  const GetDayTimeline(this._repository);

  final IReportsRepository _repository;

  Future<Result<DayTimeline>> call(String deviceId, {required String day}) async {
    final Result<List<UsageSession>> sessions = await _repository.sessions(deviceId, day: day);
    return sessions.map(DayTimeline.fromSessions);
  }
}
