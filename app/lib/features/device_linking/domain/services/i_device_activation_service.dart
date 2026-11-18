import '../../../../core/result/result.dart';
import '../entities/device_activation.dart';

/// Ativacao e desativacao do agente nativo de controle parental neste aparelho.
///
/// O agente aplica as regras com ou sem a interface aberta; aqui so se liga e desliga o
/// controle.
abstract interface class IDeviceActivationService {
  /// Grava as credenciais recebidas na aprovacao (com o endereco do servidor em uso), aplica
  /// a politica inicial e liga o controle.
  Future<Result<void>> activate(DeviceActivation activation);

  /// Verdadeiro quando o agente esta controlando este aparelho.
  Future<Result<bool>> isActivated();

  /// Desvincula o aparelho. Exige autenticacao do responsavel valida no lado nativo. Com
  /// [password] e conexao o servidor revoga o vinculo; sem senha a desativacao e local.
  /// Devolve falso quando nao foi possivel.
  Future<Result<bool>> unlink(String? password);
}
