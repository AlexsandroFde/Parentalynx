import '../../../../core/result/result.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../repositories/i_guardian_linking_repository.dart';

/// Rejeita o pedido de vinculo e recarrega a lista de aparelhos, que deixa de ter o pedido.
class RejectLinkRequest {
  const RejectLinkRequest({required this._repository, required this._devices});

  final IGuardianLinkingRepository _repository;
  final IChildDeviceRepository _devices;

  Future<Result<void>> call(String requestId) async {
    final Result<void> result = await _repository.reject(requestId);
    if (result is Ok<void>) {
      await _devices.refresh();
    }
    return result;
  }
}
