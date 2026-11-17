import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';

/// Elevacao da sessao (protocolo, secao 2.2): confirma a senha administrativa para liberar
/// as operacoes marcadas com (E) por alguns minutos.
class ElevationApi {
  const ElevationApi(this._api);

  final ApiClient _api;

  /// Devolve o instante ate o qual a sessao fica elevada. Senha errada lanca `ApiFailure`
  /// com o codigo `invalid_credentials`, e excesso de tentativas, `account_locked`.
  Future<int> elevate(String password) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/session/elevate',
      body: <String, Object?>{'password': password},
    );
    return json.integer('elevatedUntil');
  }
}

final Provider<ElevationApi> elevationApiProvider = Provider<ElevationApi>(
  (Ref ref) => ElevationApi(ref.watch(apiClientProvider)),
);
