import '../../../../core/network/server_endpoint.dart';
import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/device_activation.dart';
import '../../domain/services/i_device_activation_service.dart';

/// Liga e desliga o agente nativo ([ChildAgentApi]).
///
/// As credenciais vao junto com o endereco do servidor em uso neste aparelho: o agente passa
/// a sincronizar sozinho com ele, com ou sem a interface aberta.
class NativeDeviceActivationService implements IDeviceActivationService {
  const NativeDeviceActivationService({required this._api, required this._endpoint});

  final ChildAgentApi _api;
  final ServerEndpoint _endpoint;

  @override
  Future<Result<void>> activate(DeviceActivation activation) {
    return callNative<void>(
      () => _api.activate(
        ChildCredentials(
          serverUrl: _endpoint.url,
          deviceId: activation.deviceId,
          deviceToken: activation.deviceToken,
          offlineSecret: activation.offlineSecret,
          childName: activation.childName,
          guardianName: activation.guardianName,
        ),
        activation.policyVersion,
        activation.initialPolicy,
      ),
      fallback: 'Não foi possível ligar o controle neste aparelho.',
    );
  }

  @override
  Future<Result<bool>> isActivated() async {
    final Result<AgentStatus> status = await callNative<AgentStatus>(_api.getStatus);
    return status.map((AgentStatus value) => value.active);
  }

  @override
  Future<Result<bool>> unlink(String? password) {
    return callNative<bool>(() => _api.unlink(password));
  }
}
