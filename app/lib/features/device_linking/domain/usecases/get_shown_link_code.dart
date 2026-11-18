import '../entities/link_code.dart';
import '../repositories/i_guardian_linking_repository.dart';

/// Codigo gerado neste aparelho que ainda esta na tela de vinculacao.
class GetShownLinkCode {
  const GetShownLinkCode(this._repository);

  final IGuardianLinkingRepository _repository;

  LinkCode? call() => _repository.shownCode;
}
