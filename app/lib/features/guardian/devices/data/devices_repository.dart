import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../shared/domain/policy.dart';
import '../domain/device.dart';

/// Acesso as rotas de aparelhos, politica e comandos do responsavel (protocolo, secao 4).
///
/// As operacoes marcadas com (E) no protocolo podem lancar `ApiFailure` com
/// `isElevationRequired`. Chame-as por `runElevated` para pedir a senha e repetir.
class DevicesRepository {
  const DevicesRepository(this._api);

  final ApiClient _api;

  static String _path(String deviceId, [String suffix = '']) {
    return '/v1/guardian/devices/${Uri.encodeComponent(deviceId)}$suffix';
  }

  Future<List<Device>> listDevices() async {
    final JsonMap json = await _api.get('/v1/guardian/devices');
    return json.objList('devices').map(Device.fromJson).toList();
  }

  Future<DeviceDetail> getDevice(String deviceId) async {
    return DeviceDetail.fromJson(await _api.get(_path(deviceId)));
  }

  /// (E) Aprova um vinculo pendente, dando nome a crianca.
  Future<Device> approve(String deviceId, {required String childName}) async {
    final JsonMap json = await _api.post(
      _path(deviceId, '/approve'),
      body: <String, Object?>{'childName': childName},
    );
    return Device.fromJson(json.obj('device'));
  }

  Future<void> reject(String deviceId) async {
    await _api.post(_path(deviceId, '/reject'));
  }

  /// (E) Troca o nome da crianca.
  Future<Device> rename(String deviceId, {required String childName}) async {
    final JsonMap json = await _api.patch(
      _path(deviceId),
      body: <String, Object?>{'childName': childName},
    );
    return Device.fromJson(json.obj('device'));
  }

  /// (E) Revoga o vinculo. O aparelho desativa o controle na proxima sincronizacao.
  Future<void> revoke(String deviceId) async {
    await _api.post(_path(deviceId, '/revoke'));
  }

  /// (E) Apaga o aparelho e todo o historico.
  Future<void> deleteDevice(String deviceId) async {
    await _api.delete(_path(deviceId));
  }

  /// (E) Apaga so o historico do aparelho.
  Future<void> deleteData(String deviceId) async {
    await _api.delete(_path(deviceId, '/data'));
  }

  /// (E) Segredo do codigo de acesso offline, em Base32.
  Future<String> offlineSecret(String deviceId) async {
    final JsonMap json = await _api.get(_path(deviceId, '/offline-secret'));
    return json.str('secret');
  }

  /// (E) Todos os dados guardados do aparelho, para exportacao.
  Future<JsonMap> exportData(String deviceId) {
    return _api.get(_path(deviceId, '/export'));
  }

  /// (E) Grava a politica editada. Lanca `ApiFailure` com `isVersionConflict` se outra sessao
  /// alterou a politica depois de [baseVersion].
  Future<DevicePolicy> updatePolicy(
    String deviceId, {
    required int baseVersion,
    required Policy policy,
  }) async {
    final JsonMap json = await _api.put(
      _path(deviceId, '/policy'),
      body: <String, Object?>{
        'baseVersion': baseVersion,
        'policy': policy.toJsonWith(includeOverrides: false),
      },
    );
    return DevicePolicy.fromJson(json);
  }

  /// (E) Concede minutos extras para o dia corrente.
  Future<DevicePolicy> grantExtraTime(String deviceId, {required int minutes}) async {
    final JsonMap json = await _api.post(
      _path(deviceId, '/extra-time'),
      body: <String, Object?>{'minutes': minutes},
    );
    return DevicePolicy.fromJson(json);
  }

  /// (E) Bloqueia o aparelho agora. [until] nulo significa ate desbloquear manualmente.
  Future<DevicePolicy> lock(String deviceId, {int? until}) async {
    final JsonMap json = await _api.post(
      _path(deviceId, '/lock'),
      body: <String, Object?>{'until': until},
    );
    return DevicePolicy.fromJson(json);
  }

  /// (E) Encerra o bloqueio manual.
  Future<DevicePolicy> unlock(String deviceId) async {
    return DevicePolicy.fromJson(await _api.post(_path(deviceId, '/unlock')));
  }

  /// (E) Suspende regras por alguns minutos.
  Future<DevicePolicy> suspend(
    String deviceId, {
    required int minutes,
    required List<SuspensionScope> scopes,
  }) async {
    final JsonMap json = await _api.post(
      _path(deviceId, '/suspension'),
      body: <String, Object?>{
        'minutes': minutes,
        'scopes': scopes.map((SuspensionScope scope) => scope.code).toList(),
      },
    );
    return DevicePolicy.fromJson(json);
  }

  /// (E) Encerra a suspensao de regras.
  Future<DevicePolicy> clearSuspension(String deviceId) async {
    return DevicePolicy.fromJson(await _api.delete(_path(deviceId, '/suspension')));
  }
}

final Provider<DevicesRepository> devicesRepositoryProvider = Provider<DevicesRepository>(
  (Ref ref) => DevicesRepository(ref.watch(apiClientProvider)),
);
