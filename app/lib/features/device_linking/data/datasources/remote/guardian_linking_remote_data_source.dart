import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/guardian_linking_dtos.dart';

/// Rotas de vinculacao do responsavel (protocolo, secao 3.2). Lanca `AppFailure` em erro.
class GuardianLinkingRemoteDataSource {
  const GuardianLinkingRemoteDataSource(this._api);

  final ApiClient _api;

  static String _devicePath(String deviceId, String action) {
    return '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}/$action';
  }

  Future<LinkCodeDto> createCode() async {
    return LinkCodeDto.fromJson(await _api.post('/v1/guardian/pairing-codes'));
  }

  Future<LinkingOverviewDto> active() async {
    return LinkingOverviewDto.fromJson(await _api.get('/v1/guardian/pairing-codes/active'));
  }

  Future<void> cancelCode(String codeId) {
    return _api.delete('/v1/guardian/pairing-codes/${Uri.encodeComponent(codeId)}');
  }

  Future<LinkRequestDto> approve(String deviceId, {required String childName}) async {
    final JsonMap json = await _api.post(
      _devicePath(deviceId, 'approve'),
      body: <String, Object?>{'childName': childName},
    );
    return LinkRequestDto.fromJson(json.obj('device'));
  }

  Future<void> reject(String deviceId) => _api.post(_devicePath(deviceId, 'reject'));
}
