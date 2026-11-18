import '../../../../core/result/result.dart';
import '../entities/child_time_request.dart';
import '../services/i_screen_time_service.dart';

/// Pedidos de tempo feitos neste aparelho, do mais recente para o mais antigo.
class GetOwnTimeRequests {
  const GetOwnTimeRequests(this._service);

  final IScreenTimeService _service;

  Future<Result<List<ChildTimeRequest>>> call() async {
    final Result<List<ChildTimeRequest>> requests = await _service.ownTimeRequests();
    return requests.map(
      (List<ChildTimeRequest> list) => <ChildTimeRequest>[...list]
        ..sort((ChildTimeRequest a, ChildTimeRequest b) => b.createdAtMs.compareTo(a.createdAtMs)),
    );
  }
}
