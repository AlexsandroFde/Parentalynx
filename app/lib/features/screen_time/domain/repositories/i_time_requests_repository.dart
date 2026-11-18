import '../../../../core/result/result.dart';
import '../entities/time_request.dart';

/// Pedidos de tempo adicional no servidor, vistos pelo responsavel (protocolo, secao 4).
abstract interface class ITimeRequestsRepository {
  /// Pedidos de um aparelho, do mais novo para o mais antigo. [status] nulo traz todos.
  Future<Result<List<TimeRequest>>> list(String deviceId, {TimeRequestStatus? status});

  /// (E) Aprova um pedido concedendo [minutes].
  Future<Result<TimeRequest>> approve(String requestId, {required int minutes});

  /// (E) Nega um pedido.
  Future<Result<TimeRequest>> deny(String requestId);
}
