import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/time_request.dart';
import '../repositories/i_time_requests_repository.dart';

/// Pedidos de tempo de varios aparelhos, juntos, do mais novo para o mais antigo.
class ListTimeRequests {
  const ListTimeRequests(this._repository);

  final ITimeRequestsRepository _repository;

  Future<Result<List<TimeRequest>>> call(List<String> deviceIds) async {
    final List<Result<List<TimeRequest>>> perDevice = await Future.wait(
      <Future<Result<List<TimeRequest>>>>[
        for (final String deviceId in deviceIds) _repository.list(deviceId),
      ],
    );
    final List<TimeRequest> all = <TimeRequest>[];
    for (final Result<List<TimeRequest>> result in perDevice) {
      switch (result) {
        case Ok<List<TimeRequest>>(:final List<TimeRequest> value):
          all.addAll(value);
        case Err<List<TimeRequest>>(:final AppFailure failure):
          return Err<List<TimeRequest>>(failure);
      }
    }
    all.sort((TimeRequest a, TimeRequest b) => b.createdAt.compareTo(a.createdAt));
    return Ok<List<TimeRequest>>(all);
  }
}
