import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/report_dtos.dart';

/// Rotas de relatorios do responsavel (protocolo, secoes 4 e 6). Lanca `AppFailure` em erro.
class ReportsRemoteDataSource {
  const ReportsRemoteDataSource(this._api);

  final ApiClient _api;

  static String _path(String deviceId, String suffix) {
    return '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}$suffix';
  }

  Future<ReportSummaryDto> summary(
    String deviceId, {
    required String from,
    required String to,
  }) async {
    final JsonMap json = await _api.get(
      _path(deviceId, '/reports/summary'),
      query: <String, String?>{'from': from, 'to': to},
    );
    return ReportSummaryDto.fromJson(json);
  }

  Future<List<UsageSessionDto>> sessions(String deviceId, {required String day}) async {
    final JsonMap json = await _api.get(
      _path(deviceId, '/sessions'),
      query: <String, String?>{'day': day},
    );
    return json.objList('sessions').map(UsageSessionDto.fromJson).toList();
  }

  Future<CursorPageDto<DeviceEventDto>> events(
    String deviceId, {
    required String from,
    required String to,
    required List<String> types,
    required int limit,
    String? before,
  }) async {
    final JsonMap json = await _api.get(
      _path(deviceId, '/events'),
      query: <String, String?>{
        'from': from,
        'to': to,
        'types': types.isEmpty ? null : types.join(','),
        'before': before,
        'limit': '$limit',
      },
    );
    return CursorPageDto<DeviceEventDto>.fromJson(json, 'events', DeviceEventDto.fromJson);
  }

  Future<CursorPageDto<BrowsingEntryDto>> browsing(
    String deviceId, {
    required String from,
    required String to,
    required int limit,
    String? before,
  }) async {
    final JsonMap json = await _api.get(
      _path(deviceId, '/browsing'),
      query: <String, String?>{'from': from, 'to': to, 'before': before, 'limit': '$limit'},
    );
    return CursorPageDto<BrowsingEntryDto>.fromJson(json, 'entries', BrowsingEntryDto.fromJson);
  }
}
