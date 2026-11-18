import '../../../../core/result/result.dart';
import '../entities/versioned_policy.dart';
import '../repositories/i_device_policy_repository.dart';

/// Politica atual de um aparelho, com a versao do servidor.
class GetDevicePolicy {
  const GetDevicePolicy(this._repository);

  final IDevicePolicyRepository _repository;

  Future<Result<VersionedPolicy>> call(String deviceId) => _repository.fetch(deviceId);
}
