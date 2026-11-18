import '../../../../core/result/result.dart';
import '../../domain/entities/browsing_entry.dart';
import '../../domain/entities/cursor_page.dart';
import '../../domain/entities/device_event.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/entities/usage_session.dart';
import '../../domain/repositories/i_reports_repository.dart';
import '../datasources/remote/reports_remote_data_source.dart';
import '../dto/report_dtos.dart';
import '../mappers/report_mapper.dart';

/// Relatorios pela API.
class ApiReportsRepository implements IReportsRepository {
  const ApiReportsRepository(this._remote);

  final ReportsRemoteDataSource _remote;

  @override
  Future<Result<ReportSummary>> summary(
    String deviceId, {
    required String from,
    required String to,
  }) {
    return Result.guard(
      () async => ReportMapper.summary(await _remote.summary(deviceId, from: from, to: to)),
    );
  }

  @override
  Future<Result<List<UsageSession>>> sessions(String deviceId, {required String day}) {
    return Result.guard(() async {
      final List<UsageSessionDto> sessions = await _remote.sessions(deviceId, day: day);
      return sessions.map(ReportMapper.session).toList();
    });
  }

  @override
  Future<Result<CursorPage<DeviceEvent>>> events(
    String deviceId, {
    required String from,
    required String to,
    List<String> types = const <String>[],
    String? before,
    int limit = 50,
  }) {
    return Result.guard(() async {
      final CursorPageDto<DeviceEventDto> page = await _remote.events(
        deviceId,
        from: from,
        to: to,
        types: types,
        before: before,
        limit: limit,
      );
      return ReportMapper.page<DeviceEventDto, DeviceEvent>(page, ReportMapper.event);
    });
  }

  @override
  Future<Result<CursorPage<BrowsingEntry>>> browsing(
    String deviceId, {
    required String from,
    required String to,
    String? before,
    int limit = 50,
  }) {
    return Result.guard(() async {
      final CursorPageDto<BrowsingEntryDto> page = await _remote.browsing(
        deviceId,
        from: from,
        to: to,
        before: before,
        limit: limit,
      );
      return ReportMapper.page<BrowsingEntryDto, BrowsingEntry>(page, ReportMapper.browsing);
    });
  }
}
