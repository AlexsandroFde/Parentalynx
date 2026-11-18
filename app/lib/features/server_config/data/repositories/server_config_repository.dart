import '../../../../core/network/api_client.dart';
import '../../../../core/network/server_endpoint.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/i_server_config_repository.dart';

/// Endereco do servidor guardado pelo [ServerEndpoint] do nucleo, que o cliente da API le a
/// cada chamada.
class ServerConfigRepository implements IServerConfigRepository {
  const ServerConfigRepository({required this._endpoint, required this._api});

  final ServerEndpoint _endpoint;
  final ApiClient _api;

  @override
  String get current => _endpoint.url;

  @override
  Stream<String> watch() => _endpoint.changes;

  @override
  Future<void> save(String url) => _endpoint.update(url);

  @override
  Future<Result<void>> probe() {
    return Result.guard<void>(() async {
      await _api.get('/v1/meta', auth: ApiAuth.none);
    });
  }
}
