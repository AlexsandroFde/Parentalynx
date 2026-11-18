import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/server_address_policy.dart';
import '../repositories/i_server_config_repository.dart';

/// Troca o endereco do servidor.
///
/// O endereco precisa atender a regra do build e ter um servidor ParentaLynx respondendo. Se
/// a conferencia falhar, o endereco anterior volta a valer.
class UpdateServerAddress {
  const UpdateServerAddress({required this._repository, required this._policy});

  final IServerConfigRepository _repository;
  final ServerAddressPolicy _policy;

  Future<Result<void>> call(String url) async {
    final String clean = url.trim();
    if (!_policy.accepts(clean)) {
      return Err<void>(ValidationFailure(_policy.requirementMessage));
    }
    final String previous = _repository.current;
    await _repository.save(clean);
    final Result<void> probe = await _repository.probe();
    if (probe.isErr) {
      await _repository.save(previous);
    }
    return probe;
  }
}
