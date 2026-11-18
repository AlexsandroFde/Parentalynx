import '../../../../core/result/result.dart';
import '../../../device_linking/domain/entities/device_identity.dart';
import '../../../device_linking/domain/usecases/get_device_identity.dart';
import '../entities/permission_facts.dart';
import '../entities/permission_plan.dart';
import '../services/i_platform_permission_service.dart';

/// Le o estado das permissoes do controle e monta os passos que faltam.
///
/// O fabricante decide se o passo de inicio automatico aparece. Na primeira leitura ele vem
/// do sistema; nas releituras (ao voltar das configuracoes) quem chama repassa o ja
/// conhecido.
class CheckPermissions {
  const CheckPermissions({required this._permissions, required this._getDeviceIdentity});

  final IPlatformPermissionService _permissions;
  final GetDeviceIdentity _getDeviceIdentity;

  Future<Result<PermissionPlan>> call({String? manufacturer}) async {
    final Result<PermissionFacts> facts = await _permissions.permissions();
    if (facts case Err<PermissionFacts>(:final failure)) {
      return Err<PermissionPlan>(failure);
    }
    // Sem o fabricante, so o passo de inicio automatico deixa de aparecer.
    final String maker =
        manufacturer ??
        (await _getDeviceIdentity()).fold(
          onOk: (DeviceIdentity identity) => identity.manufacturer,
          onErr: (_) => '',
        );
    return facts.map((PermissionFacts value) => PermissionPlan(facts: value, manufacturer: maker));
  }
}
