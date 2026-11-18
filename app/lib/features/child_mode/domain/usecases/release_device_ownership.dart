import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/i_device_management_service.dart';

/// O aparelho deixa de ser um dispositivo gerenciado (Device Owner). Exige a autenticacao do
/// responsavel valida.
class ReleaseDeviceOwnership {
  const ReleaseDeviceOwnership(this._management);

  final IDeviceManagementService _management;

  Future<Result<void>> call() async {
    final Result<bool> released = await _management.releaseDeviceOwner();
    return switch (released) {
      Ok<bool>(value: true) => okVoid,
      Ok<bool>() => const Err<void>(
        UnexpectedFailure('O sistema não aceitou a mudança. Tente de novo.'),
      ),
      Err<bool>(:final failure) => Err<void>(failure),
    };
  }
}
