import 'dart:convert';

import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/child_device_dto.dart';

/// Rotas de aparelhos do responsavel (protocolo, secao 4). Lanca `AppFailure` em erro.
class ChildDeviceRemoteDataSource {
  const ChildDeviceRemoteDataSource(this._api);

  final ApiClient _api;

  static String _path(String deviceId, [String suffix = '']) {
    return '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}$suffix';
  }

  Future<List<ChildDeviceDto>> list() async {
    final JsonMap json = await _api.get('/v1/guardian/devices');
    return json.objList('devices').map(ChildDeviceDto.fromJson).toList();
  }

  Future<ChildDeviceDto> rename(String deviceId, {required String childName}) async {
    final JsonMap json = await _api.patch(
      _path(deviceId),
      body: <String, Object?>{'childName': childName},
    );
    return ChildDeviceDto.fromJson(json.obj('device'));
  }

  Future<void> revoke(String deviceId) async {
    await _api.post(_path(deviceId, '/revoke'));
  }

  Future<void> delete(String deviceId) async {
    await _api.delete(_path(deviceId));
  }

  Future<void> deleteData(String deviceId) async {
    await _api.delete(_path(deviceId, '/data'));
  }

  Future<String> offlineSecret(String deviceId) async {
    final JsonMap json = await _api.get(_path(deviceId, '/offline-secret'));
    return json.str('secret');
  }

  /// Dados do aparelho em JSON formatado, prontos para virar arquivo.
  Future<String> exportData(String deviceId) async {
    final JsonMap json = await _api.get(_path(deviceId, '/export'));
    return const JsonEncoder.withIndent('  ').convert(json.raw);
  }
}
