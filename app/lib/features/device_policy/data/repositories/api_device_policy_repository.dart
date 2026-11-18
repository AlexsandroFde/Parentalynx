import '../../../../core/result/result.dart';
import '../../domain/entities/policy.dart';
import '../../domain/entities/versioned_policy.dart';
import '../../domain/repositories/i_device_policy_repository.dart';
import '../../domain/repositories/i_policy_command_repository.dart';
import '../datasources/remote/device_policy_remote_data_source.dart';
import '../dto/policy_dto.dart';
import '../mappers/policy_mapper.dart';

/// Politica e comandos dos aparelhos pela API.
class ApiDevicePolicyRepository implements IDevicePolicyRepository, IPolicyCommandRepository {
  const ApiDevicePolicyRepository(this._remote);

  final DevicePolicyRemoteDataSource _remote;

  Future<Result<VersionedPolicy>> _run(Future<VersionedPolicyDto> Function() call) {
    return Result.guard(() async => PolicyMapper.versioned(await call()));
  }

  @override
  Future<Result<VersionedPolicy>> fetch(String deviceId) => _run(() => _remote.fetch(deviceId));

  @override
  Future<Result<VersionedPolicy>> replace(
    String deviceId, {
    required int baseVersion,
    required Policy policy,
  }) {
    return _run(
      () => _remote.replace(deviceId, baseVersion: baseVersion, policy: PolicyMapper.toDto(policy)),
    );
  }

  @override
  Future<Result<VersionedPolicy>> grantExtraTime(String deviceId, {required int minutes}) {
    return _run(() => _remote.grantExtraTime(deviceId, minutes: minutes));
  }

  @override
  Future<Result<VersionedPolicy>> lock(String deviceId, {int? until}) {
    return _run(() => _remote.lock(deviceId, until: until));
  }

  @override
  Future<Result<VersionedPolicy>> unlock(String deviceId) => _run(() => _remote.unlock(deviceId));

  @override
  Future<Result<VersionedPolicy>> suspend(
    String deviceId, {
    required int minutes,
    required List<SuspensionScope> scopes,
  }) {
    return _run(
      () => _remote.suspend(
        deviceId,
        minutes: minutes,
        scopes: scopes.map(PolicyMapper.suspensionScopeCode).toList(),
      ),
    );
  }

  @override
  Future<Result<VersionedPolicy>> clearSuspension(String deviceId) {
    return _run(() => _remote.clearSuspension(deviceId));
  }
}
