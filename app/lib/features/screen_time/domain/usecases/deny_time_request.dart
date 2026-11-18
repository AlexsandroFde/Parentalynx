import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../entities/time_request.dart';
import '../repositories/i_time_requests_repository.dart';

/// Nega um pedido de tempo. A crianca e avisada no aparelho. Operacao administrativa.
class DenyTimeRequest {
  const DenyTimeRequest({
    required this._repository,
    required this._devices,
    required this._elevated,
  });

  final ITimeRequestsRepository _repository;
  final IChildDeviceRepository _devices;
  final RunElevated _elevated;

  Future<Result<TimeRequest>> call(String requestId) async {
    final Result<TimeRequest> result = await _elevated<TimeRequest>(
      () => _repository.deny(requestId),
    );
    if (result.isOk) {
      // A contagem de pedidos pendentes do aparelho muda.
      await _devices.refresh();
    }
    return result;
  }
}
