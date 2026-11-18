import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../entities/time_request.dart';
import '../repositories/i_time_requests_repository.dart';

/// Aprova um pedido de tempo concedendo alguns minutos para hoje. Operacao administrativa.
///
/// Depois de aprovar, atualiza a lista de aparelhos: a contagem de pedidos pendentes e a
/// versao da politica (o tempo concedido vira tempo extra) mudam.
class ApproveTimeRequest {
  const ApproveTimeRequest({
    required this._repository,
    required this._devices,
    required this._elevated,
  });

  final ITimeRequestsRepository _repository;
  final IChildDeviceRepository _devices;
  final RunElevated _elevated;

  Future<Result<TimeRequest>> call(String requestId, {required int minutes}) async {
    if (minutes < 1 || minutes > TimeRequest.maxGrantMinutes) {
      return const Err<TimeRequest>(
        ValidationFailure('Escolha entre 1 minuto e 12 horas de tempo extra.'),
      );
    }
    final Result<TimeRequest> result = await _elevated<TimeRequest>(
      () => _repository.approve(requestId, minutes: minutes),
    );
    if (result.isOk) {
      await _devices.refresh();
    }
    return result;
  }
}
