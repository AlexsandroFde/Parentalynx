import '../../../../core/result/result.dart';
import '../repositories/i_guardian_linking_repository.dart';

/// Cancela o codigo mostrado. Para vincular um aparelho sera preciso gerar outro.
class CancelLinkCode {
  const CancelLinkCode(this._repository);

  final IGuardianLinkingRepository _repository;

  Future<Result<void>> call(String codeId) => _repository.cancelCode(codeId);
}
