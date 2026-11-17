import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../apps/data/apps_repository.dart' show noRetry;
import '../domain/report_models.dart';

/// Acesso as rotas de relatorios (protocolo, secoes 4 e 6).
class ReportsRepository {
  const ReportsRepository(this._api);

  final ApiClient _api;

  static String _path(String deviceId, String suffix) {
    return '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}$suffix';
  }

  Future<ReportSummary> summary(String deviceId, {required String from, required String to}) async {
    final JsonMap json = await _api.get(
      _path(deviceId, '/reports/summary'),
      query: <String, String?>{'from': from, 'to': to},
    );
    return ReportSummary.fromJson(json);
  }

  Future<List<UsageSession>> sessions(String deviceId, {required String day}) async {
    final JsonMap json = await _api.get(
      _path(deviceId, '/sessions'),
      query: <String, String?>{'day': day},
    );
    return json.objList('sessions').map(UsageSession.fromJson).toList();
  }

  /// Eventos do periodo, do mais recente para o mais antigo. [types] vazio traz todos.
  Future<ResultPage<DeviceEvent>> events(
    String deviceId, {
    required String from,
    required String to,
    List<String> types = const <String>[],
    String? before,
    int limit = 50,
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
    return ResultPage<DeviceEvent>(
      items: json.objList('events').map(DeviceEvent.fromJson).toList(),
      nextBefore: _cursor(json),
    );
  }

  Future<ResultPage<BrowsingEntry>> browsing(
    String deviceId, {
    required String from,
    required String to,
    String? before,
    int limit = 50,
  }) async {
    final JsonMap json = await _api.get(
      _path(deviceId, '/browsing'),
      query: <String, String?>{'from': from, 'to': to, 'before': before, 'limit': '$limit'},
    );
    return ResultPage<BrowsingEntry>(
      items: json.objList('entries').map(BrowsingEntry.fromJson).toList(),
      nextBefore: _cursor(json),
    );
  }

  /// O cursor e opaco para o app: numero ou texto, conforme o servidor mandar.
  static String? _cursor(JsonMap json) {
    final Object? value = json.raw['nextBefore'];
    return value == null ? null : '$value';
  }
}

final Provider<ReportsRepository> reportsRepositoryProvider = Provider<ReportsRepository>(
  (Ref ref) => ReportsRepository(ref.watch(apiClientProvider)),
);

/// Consulta de um relatorio: aparelho e intervalo de dias.
typedef ReportQuery = ({String deviceId, String from, String to});

final FutureProviderFamily<ReportSummary, ReportQuery> reportSummaryProvider = FutureProvider
    .autoDispose
    .family<ReportSummary, ReportQuery>((Ref ref, ReportQuery query) {
      return ref
          .watch(reportsRepositoryProvider)
          .summary(query.deviceId, from: query.from, to: query.to);
    }, retry: noRetry);

/// Sessoes de um dia de um aparelho.
typedef SessionsQuery = ({String deviceId, String day});

final FutureProviderFamily<List<UsageSession>, SessionsQuery> daySessionsProvider = FutureProvider
    .autoDispose
    .family<List<UsageSession>, SessionsQuery>((Ref ref, SessionsQuery query) {
      return ref.watch(reportsRepositoryProvider).sessions(query.deviceId, day: query.day);
    }, retry: noRetry);
