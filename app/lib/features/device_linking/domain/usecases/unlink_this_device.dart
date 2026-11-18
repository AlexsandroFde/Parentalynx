import '../../../../core/result/result.dart';
import '../../../user_role/domain/entities/user_role.dart';
import '../../../user_role/domain/usecases/change_user_role.dart';
import '../entities/link_state.dart';
import '../repositories/i_link_state_repository.dart';
import '../services/i_device_activation_service.dart';

/// Desvincula este aparelho pela area do responsavel e volta para a escolha de modo.
///
/// Exige a autenticacao do responsavel valida no lado nativo. Com a senha e conexao, o
/// servidor revoga o vinculo; com o codigo offline, a desativacao e local e o servidor e
/// avisado depois. Devolve falso quando o agente nao conseguiu desvincular.
class UnlinkThisDevice {
  const UnlinkThisDevice({
    required this._activation,
    required this._linkState,
    required this._changeUserRole,
  });

  final IDeviceActivationService _activation;
  final ILinkStateRepository _linkState;
  final ChangeUserRole _changeUserRole;

  Future<Result<bool>> call({String? password}) async {
    final Result<bool> unlinked = await _activation.unlink(password);
    if (unlinked case Ok<bool>(value: true)) {
      // Primeiro o aparelho fica sem vinculo (as telas protegidas saem) e so entao o modo e
      // trocado. Se a troca falhar, a tela do codigo tambem deixa voltar a escolha de modo.
      _linkState.update(const LinkState(LinkPhase.unlinked));
      return (await _changeUserRole(UserRole.unset)).map((void _) => true);
    }
    return unlinked;
  }
}
