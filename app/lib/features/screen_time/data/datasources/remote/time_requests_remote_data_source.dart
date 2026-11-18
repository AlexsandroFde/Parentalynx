import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/time_request_dto.dart';

/// Rotas de pedidos de tempo do responsavel. Lanca `AppFailure` em erro.
class TimeRequestsRemoteDataSource {
  const TimeRequestsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<TimeRequestDto>> list(String deviceId, {String? status}) async {
    final JsonMap json = await _api.get(
      '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}/time-requests',
      query: <String, String?>{'status': status},
    );
    return json.objList('requests').map(TimeRequestDto.fromJson).toList();
  }

  /// Aprova ([minutes] obrigatorio) ou nega um pedido.
  Future<TimeRequestDto> resolve(String requestId, {required bool approve, int? minutes}) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/time-requests/${Uri.encodeComponent(requestId)}/resolve',
      body: <String, Object?>{
        'action': approve ? 'approve' : 'deny',
        if (approve && minutes != null) 'minutes': minutes,
      },
    );
    return TimeRequestDto.fromJson(json.obj('request'));
  }
}
