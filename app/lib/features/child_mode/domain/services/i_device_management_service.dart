import '../../../../core/result/result.dart';

/// Nivel de gerenciamento do aparelho: administrador do dispositivo e Device Owner.
abstract interface class IDeviceManagementService {
  /// Abre o pedido do sistema para ativar o administrador do dispositivo.
  Future<Result<void>> requestDeviceAdmin();

  /// Desativa o administrador. Exige autenticacao do responsavel valida no lado nativo.
  Future<Result<void>> removeDeviceAdmin();

  /// Abre mao do modo Device Owner. Exige autenticacao do responsavel valida no lado nativo.
  /// Falso quando o sistema nao aceitou.
  Future<Result<bool>> releaseDeviceOwner();
}
