import '../../../../core/json/json_reader.dart';
import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/policy.dart';
import '../../domain/services/i_device_policy_service.dart';
import '../dto/policy_dto.dart';
import '../mappers/policy_mapper.dart';

/// Politica em vigor lida do agente nativo ([ChildAgentApi.getPolicyJson]).
class NativeDevicePolicyService implements IDevicePolicyService {
  const NativeDevicePolicyService(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<Policy?>> activePolicy() async {
    final Result<String?> source = await callNative<String?>(_api.getPolicyJson);
    return source.map(_parse);
  }

  /// Texto vazio ou fora do formato vira "sem politica": a tela mostra so o que o agente
  /// informa no retrato de estado.
  static Policy? _parse(String? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    try {
      return PolicyMapper.policy(PolicyDto.fromJson(decodeJsonObject(source)));
    } on JsonFormatException {
      return null;
    }
  }
}
