import '../../../../core/result/result.dart';
import '../../domain/entities/time_request.dart';
import '../../domain/repositories/i_time_requests_repository.dart';
import '../datasources/remote/time_requests_remote_data_source.dart';
import '../dto/time_request_dto.dart';
import '../mappers/time_request_mapper.dart';

/// Pedidos de tempo pela API.
class ApiTimeRequestsRepository implements ITimeRequestsRepository {
  const ApiTimeRequestsRepository(this._remote);

  final TimeRequestsRemoteDataSource _remote;

  @override
  Future<Result<List<TimeRequest>>> list(String deviceId, {TimeRequestStatus? status}) {
    return Result.guard(() async {
      final List<TimeRequestDto> dtos = await _remote.list(
        deviceId,
        status: status == null ? null : TimeRequestMapper.statusCode(status),
      );
      return dtos.map(TimeRequestMapper.request).toList();
    });
  }

  @override
  Future<Result<TimeRequest>> approve(String requestId, {required int minutes}) {
    return Result.guard(() async {
      return TimeRequestMapper.request(
        await _remote.resolve(requestId, approve: true, minutes: minutes),
      );
    });
  }

  @override
  Future<Result<TimeRequest>> deny(String requestId) {
    return Result.guard(() async {
      return TimeRequestMapper.request(await _remote.resolve(requestId, approve: false));
    });
  }
}
