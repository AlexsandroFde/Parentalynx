import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../auth/domain/guardian_account.dart';
import '../domain/alert.dart';
import '../domain/alerts_repository.dart';

class ApiAlertsRepository implements AlertsRepository {
  const ApiAlertsRepository(this._api);

  final ApiClient _api;

  @override
  Future<AlertsPage> list({
    int? after,
    int? before,
    int limit = 30,
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
    return AlertsPage.fromJson(json);
  }

  @override
  Future<int> markRead({List<int>? ids, bool all = false}) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/alerts/read',
      body: <String, Object?>{'ids': ?ids, if (all) 'all': true},
    );
    return json.intOr('unread', fallback: 0);
  }

  @override
  Future<Map<String, bool>> updateNotificationPrefs(Map<String, bool> prefs) async {
    final JsonMap json = await _api.put('/v1/guardian/notification-prefs', body: prefs);
    final JsonMap? result = json.objOrNull('notificationPrefs');
    return result == null ? prefs : readNotificationPrefs(result);
  }
}

final Provider<AlertsRepository> alertsRepositoryProvider = Provider<AlertsRepository>(
  (Ref ref) => ApiAlertsRepository(ref.watch(apiClientProvider)),
);
