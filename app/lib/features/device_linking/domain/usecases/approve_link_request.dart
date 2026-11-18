import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../entities/link_request.dart';
import '../repositories/i_guardian_linking_repository.dart';
import '../services/link_request_rules.dart';

/// (E) Aprova o pedido de vinculo dando nome a crianca e recarrega a lista de aparelhos, que
/// passa a ter o aparelho novo.
class ApproveLinkRequest {
  const ApproveLinkRequest({
    required this._repository,
    required this._devices,
    required this._runElevated,
  });

  final IGuardianLinkingRepository _repository;
  final IChildDeviceRepository _devices;
  final RunElevated _runElevated;

  /// Devolve o aparelho vinculado. O identificador pode ser o do cadastro antigo, quando o
  /// aparelho ja era conhecido da conta.
  Future<Result<LinkRequest>> call(String requestId, {required String childName}) async {
    final String name = childName.trim();
    final String? error = LinkRequestRules.childNameError(name);
    if (error != null) {
      return Err<LinkRequest>(ValidationFailure(error));
    }
    final Result<LinkRequest> result = await _runElevated<LinkRequest>(
      () => _repository.approve(requestId, childName: name),
    );
    if (result is Ok<LinkRequest>) {
      // Sem rede a lista se atualiza no proximo aviso; a aprovacao ja valeu.
      await _devices.refresh();
    }
    return result;
  }
}
