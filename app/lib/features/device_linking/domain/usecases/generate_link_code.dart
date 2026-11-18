import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../entities/link_code.dart';
import '../repositories/i_guardian_linking_repository.dart';

/// (E) Gera um codigo de vinculacao. O codigo anterior, se houver, deixa de valer.
class GenerateLinkCode {
  const GenerateLinkCode({required this._repository, required this._runElevated});

  final IGuardianLinkingRepository _repository;
  final RunElevated _runElevated;

  Future<Result<LinkCode>> call() => _runElevated<LinkCode>(_repository.createCode);
}
