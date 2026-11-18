import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../entities/child_device.dart';
import '../repositories/i_child_device_repository.dart';
import '../services/child_name_policy.dart';

/// Troca o nome da crianca de um aparelho. Operacao administrativa.
class RenameChildDevice {
  const RenameChildDevice({required this._repository, required this._elevated});

  final IChildDeviceRepository _repository;
  final RunElevated _elevated;

  Future<Result<ChildDevice>> call(String deviceId, {required String childName}) async {
    final String? invalid = ChildNamePolicy.error(childName);
    if (invalid != null) {
      return Err<ChildDevice>(ValidationFailure(invalid));
    }
    final String name = childName.trim();
    final Result<ChildDevice> result = await _elevated<ChildDevice>(
      () => _repository.rename(deviceId, childName: name),
    );
    if (result case Ok<ChildDevice>(:final ChildDevice value)) {
      _repository.upsert(value);
    }
    return result;
  }
}
