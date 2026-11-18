import '../../../../core/result/result.dart';
import '../entities/child_time_request.dart';

/// Tempo de tela no aparelho da crianca, pelo agente nativo: pedidos de tempo adicional.
///
/// A contagem do tempo e o bloqueio ao fim da cota sao feitos pelo agente, com ou sem a
/// interface aberta.
abstract interface class IScreenTimeService {
  /// Registra um pedido de tempo. Devolve o identificador do pedido.
  Future<Result<String>> submitTimeRequest({int? minutes, String? message});

  /// Pedidos feitos neste aparelho.
  Future<Result<List<ChildTimeRequest>>> ownTimeRequests();
}
