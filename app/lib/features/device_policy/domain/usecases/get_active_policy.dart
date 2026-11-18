import '../../../../core/result/result.dart';
import '../entities/policy.dart';
import '../services/i_device_policy_service.dart';

/// Politica em vigor neste aparelho (modo crianca), para a crianca ver o que vale.
class GetActivePolicy {
  const GetActivePolicy(this._service);

  final IDevicePolicyService _service;

  Future<Result<Policy?>> call() => _service.activePolicy();
}
