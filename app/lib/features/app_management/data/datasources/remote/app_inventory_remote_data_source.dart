import 'dart:typed_data';

import '../../../../../core/network/api_client.dart';
import '../../dto/app_entry_dto.dart';

/// Inventario de apps pela API (protocolo, secao 5.1). Lanca `AppFailure` em erro.
class AppInventoryRemoteDataSource {
  const AppInventoryRemoteDataSource(this._api);

  final ApiClient _api;

  Future<DeviceAppsDto> listApps(String deviceId) async {
    return DeviceAppsDto.fromJson(
      await _api.get('/v1/guardian/devices/${Uri.encodeComponent(deviceId)}/apps'),
    );
  }

  /// Baixa o icone autenticado. O caminho vem do inventario e pode trazer parametros.
  Future<Uint8List> fetchIcon(String iconPath) {
    final Uri relative = Uri.parse(iconPath);
    return _api.getBytes(relative.path, query: relative.queryParameters);
  }
}
