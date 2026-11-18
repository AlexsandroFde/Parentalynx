import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_child_device_repository.dart';

/// Exporta todos os dados guardados do aparelho em JSON. Operacao administrativa.
class ExportChildDeviceData {
  const ExportChildDeviceData({required this._repository, required this._elevated});

  final IChildDeviceRepository _repository;
  final RunElevated _elevated;

  Future<Result<String>> call(String deviceId) {
    return _elevated<String>(() => _repository.exportData(deviceId));
  }
}
