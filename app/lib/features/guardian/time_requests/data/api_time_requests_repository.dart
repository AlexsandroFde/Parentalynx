import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../domain/time_request.dart';
import '../domain/time_requests_repository.dart';

class ApiTimeRequestsRepository implements TimeRequestsRepository {
  const ApiTimeRequestsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<TimeRequest>> list(String deviceId, {TimeRequestStatus? status}) async {
    final JsonMap json = await _api.get(
      '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}/time-requests',
      query: <String, String?>{'status': status?.code},
    );
    return json.objList('requests').map(TimeRequest.fromJson).toList();
  }

  @override
  Future<TimeRequest> resolve(String requestId, {required bool approve, int? minutes}) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/time-requests/${Uri.encodeComponent(requestId)}/resolve',
      body: <String, Object?>{
        'action': approve ? 'approve' : 'deny',
        if (approve && minutes != null) 'minutes': minutes,
      },
    );
    return TimeRequest.fromJson(json.obj('request'));
  }
}

final Provider<TimeRequestsRepository> timeRequestsRepositoryProvider =
    Provider<TimeRequestsRepository>(
      (Ref ref) => ApiTimeRequestsRepository(ref.watch(apiClientProvider)),
    );
