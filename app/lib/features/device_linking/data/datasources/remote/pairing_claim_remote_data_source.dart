import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/security/pairing_code.dart';
import '../../dto/pairing_claim_dtos.dart';

/// Rotas publicas de vinculacao usadas pelo aparelho da crianca (protocolo, secao 3.2).
/// Lanca `AppFailure` em erro.
class PairingClaimRemoteDataSource {
  const PairingClaimRemoteDataSource(this._api);

  final ApiClient _api;

  Future<PairingClaimDto> claim({required String code, required DeviceIdentityDto device}) async {
    final JsonMap json = await _api.post(
      '/v1/pairing/claim',
      auth: ApiAuth.none,
      body: <String, Object?>{'code': PairingCode.normalize(code), 'device': device.toJson()},
    );
    return PairingClaimDto.fromJson(json);
  }

  /// Consulta com o token do proprio pedido, sem sessao.
  Future<PairingStatusDto> status(String pollToken) async {
    final JsonMap json = await _api.get(
      '/v1/pairing/status',
      auth: ApiAuth.none,
      bearer: pollToken,
    );
    return PairingStatusDto.fromJson(json);
  }
}
