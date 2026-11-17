import 'time_request.dart';

/// Pedidos de tempo adicional (protocolo, secao 4).
abstract interface class TimeRequestsRepository {
  /// Pedidos de um aparelho, do mais novo para o mais antigo. [status] nulo traz todos.
  Future<List<TimeRequest>> list(String deviceId, {TimeRequestStatus? status});

  /// (E) Aprova ou nega um pedido. Ao aprovar, [minutes] e o tempo concedido.
  Future<TimeRequest> resolve(String requestId, {required bool approve, int? minutes});
}
