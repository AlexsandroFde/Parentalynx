import '../../../../core/platform/native_api.g.dart';
import '../../domain/entities/child_time_request.dart';

/// Converte os pedidos informados pelo agente nativo na entidade do modo crianca.
abstract final class ChildTimeRequestMapper {
  static ChildTimeRequest request(TimeRequestInfo info) {
    return ChildTimeRequest(
      id: info.id,
      createdAtMs: info.createdAtMs,
      minutes: info.minutes,
      message: info.message,
      status: switch (info.status) {
        'approved' => ChildTimeRequestStatus.approved,
        'denied' => ChildTimeRequestStatus.denied,
        'expired' => ChildTimeRequestStatus.expired,
        _ => ChildTimeRequestStatus.pending,
      },
      grantedMinutes: info.grantedMinutes,
      delivered: info.delivered,
    );
  }
}
