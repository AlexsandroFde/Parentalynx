import '../entities/link_code.dart';
import '../repositories/i_guardian_linking_repository.dart';

/// Tira da tela o codigo que venceu sem ser usado.
class ExpireLinkCode {
  const ExpireLinkCode(this._repository);

  final IGuardianLinkingRepository _repository;

  /// Devolve verdadeiro quando [code] ja venceu em [nowMs] e deixou de ser mostrado.
  bool call(LinkCode code, {required int nowMs}) {
    if (code.expiresAt > nowMs) {
      return false;
    }
    _repository.forgetCode(code.id);
    return true;
  }
}
