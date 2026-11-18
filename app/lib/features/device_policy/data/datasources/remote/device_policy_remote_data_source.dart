import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/policy_dto.dart';

/// Rotas de politica e comandos do responsavel (protocolo, secao 4). Lanca `AppFailure` em
/// erro.
class DevicePolicyRemoteDataSource {
  const DevicePolicyRemoteDataSource(this._api);

  final ApiClient _api;

  static String _path(String deviceId, [String suffix = '']) {
    return '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}$suffix';
  }

  /// `GET /devices/:id` devolve o aparelho e a politica; aqui interessa so a politica.
  Future<VersionedPolicyDto> fetch(String deviceId) async {
    return VersionedPolicyDto.fromJson(await _api.get(_path(deviceId)));
  }

  Future<VersionedPolicyDto> replace(
    String deviceId, {
    required int baseVersion,
    required PolicyDto policy,
  }) async {
    final JsonMap json = await _api.put(
      _path(deviceId, '/policy'),
      body: <String, Object?>{
        'baseVersion': baseVersion,
        'policy': policy.toJson(includeOverrides: false),
      },
    );
    return VersionedPolicyDto.fromJson(json);
  }

  Future<VersionedPolicyDto> grantExtraTime(String deviceId, {required int minutes}) async {
    final JsonMap json = await _api.post(
      _path(deviceId, '/extra-time'),
      body: <String, Object?>{'minutes': minutes},
    );
    return VersionedPolicyDto.fromJson(json);
  }

  Future<VersionedPolicyDto> lock(String deviceId, {int? until}) async {
    final JsonMap json = await _api.post(
      _path(deviceId, '/lock'),
      body: <String, Object?>{'until': until},
    );
    return VersionedPolicyDto.fromJson(json);
  }

  Future<VersionedPolicyDto> unlock(String deviceId) async {
    return VersionedPolicyDto.fromJson(await _api.post(_path(deviceId, '/unlock')));
  }

  Future<VersionedPolicyDto> suspend(
    String deviceId, {
    required int minutes,
    required List<String> scopes,
  }) async {
    final JsonMap json = await _api.post(
      _path(deviceId, '/suspension'),
      body: <String, Object?>{'minutes': minutes, 'scopes': scopes},
    );
    return VersionedPolicyDto.fromJson(json);
  }

  Future<VersionedPolicyDto> clearSuspension(String deviceId) async {
    return VersionedPolicyDto.fromJson(await _api.delete(_path(deviceId, '/suspension')));
  }
}
