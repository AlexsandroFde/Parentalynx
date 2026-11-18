import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/child_time_request.dart';
import '../../domain/services/i_screen_time_service.dart';
import '../mappers/child_time_request_mapper.dart';

/// Pedidos de tempo pela ponte com o agente nativo ([ChildAgentApi]).
class NativeScreenTimeService implements IScreenTimeService {
  const NativeScreenTimeService(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<String>> submitTimeRequest({int? minutes, String? message}) {
    return callNative<String>(
      () => _api.submitTimeRequest(minutes, message),
      fallback: 'Não foi possível registrar o pedido. Tente de novo.',
    );
  }

  @override
  Future<Result<List<ChildTimeRequest>>> ownTimeRequests() async {
    final Result<List<TimeRequestInfo>> requests = await callNative<List<TimeRequestInfo>>(
      _api.getTimeRequests,
    );
    return requests.map(
      (List<TimeRequestInfo> list) => list.map(ChildTimeRequestMapper.request).toList(),
    );
  }
}
