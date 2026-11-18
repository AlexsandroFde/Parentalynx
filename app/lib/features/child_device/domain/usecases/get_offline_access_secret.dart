import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_child_device_repository.dart';

/// Busca o segredo do codigo de acesso offline de um aparelho. Operacao administrativa.
///
/// Com o segredo, o responsavel abre a area do responsavel no aparelho da crianca mesmo sem
/// internet (protocolo, secao 3.4).
class GetOfflineAccessSecret {
  const GetOfflineAccessSecret({required this._repository, required this._elevated});

  final IChildDeviceRepository _repository;
  final RunElevated _elevated;

  Future<Result<String>> call(String deviceId) {
    return _elevated<String>(() => _repository.offlineSecret(deviceId));
  }
}
