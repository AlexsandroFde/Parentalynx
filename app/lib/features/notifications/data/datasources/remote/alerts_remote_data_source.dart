import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/alert_dto.dart';

/// Rotas de alertas e preferencias de notificacao (protocolo, secao 2.5). Lanca `AppFailure`
/// em erro.
class AlertsRemoteDataSource {
  const AlertsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AlertsPageDto> list({
    int? after,
    int? before,
    required int limit,
    bool notifyOnly = false,
  }) async {
    final JsonMap json = await _api.get(
      '/v1/guardian/alerts',
      query: <String, String?>{
        'after': after?.toString(),
        'before': before?.toString(),
        'limit': '$limit',
        'notifyOnly': notifyOnly ? '1' : null,
      },
    );
    return AlertsPageDto.fromJson(json);
  }

  /// Devolve quantos continuam nao lidos.
  Future<int> markRead({List<int>? ids, bool all = false}) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/alerts/read',
      body: <String, Object?>{'ids': ?ids, if (all) 'all': true},
    );
    return json.intOr('unread', fallback: 0);
  }

  /// Devolve o mapa em vigor, ou nulo quando o servidor nao o devolve.
  Future<Map<String, bool>?> updateNotificationPrefs(Map<String, bool> prefs) async {
    final JsonMap json = await _api.put('/v1/guardian/notification-prefs', body: prefs);
    final JsonMap? result = json.objOrNull('notificationPrefs');
    return result == null ? null : readNotificationPrefs(result);
  }
}
