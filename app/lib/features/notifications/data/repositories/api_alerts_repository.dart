import '../../../../core/result/result.dart';
import '../../domain/entities/guardian_alert.dart';
import '../../domain/repositories/i_alerts_repository.dart';
import '../datasources/remote/alerts_remote_data_source.dart';
import '../mappers/alert_mapper.dart';

/// Central de alertas pela API.
class ApiAlertsRepository implements IAlertsRepository {
  const ApiAlertsRepository(this._remote);

  final AlertsRemoteDataSource _remote;

  @override
  Future<Result<AlertsPage>> list({
    int? after,
    int? before,
    int limit = 30,
    bool notifyOnly = false,
  }) {
    return Result.guard(() async {
      return AlertMapper.page(
        await _remote.list(after: after, before: before, limit: limit, notifyOnly: notifyOnly),
      );
    });
  }

  @override
  Future<Result<int>> markRead({List<int>? ids, bool all = false}) {
    return Result.guard(() => _remote.markRead(ids: ids, all: all));
  }

  @override
  Future<Result<Map<String, bool>>> updateNotificationPrefs(Map<String, bool> prefs) {
    return Result.guard(() async => await _remote.updateNotificationPrefs(prefs) ?? prefs);
  }
}
