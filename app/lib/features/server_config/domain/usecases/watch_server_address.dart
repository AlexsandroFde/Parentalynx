import '../entities/server_address_policy.dart';
import '../repositories/i_server_config_repository.dart';

/// Endereco do servidor em uso, para mostrar nas telas e decidir se falta configurar.
class WatchServerAddress {
  const WatchServerAddress({required this._repository, required this._policy});

  final IServerConfigRepository _repository;
  final ServerAddressPolicy _policy;

  String get current => _repository.current;

  /// Verdadeiro quando o endereco atual atende a regra do build.
  bool get isConfigured => _policy.accepts(_repository.current);

  Stream<String> call() => _repository.watch();
}
