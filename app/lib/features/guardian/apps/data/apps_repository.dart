import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../domain/app_entry.dart';

/// Inventario de apps de um aparelho (`GET /v1/guardian/devices/:id/apps`).
class AppsRepository {
  const AppsRepository(this._api);

  final ApiClient _api;

  Future<DeviceApps> listApps(String deviceId) async {
    return DeviceApps.fromJson(
      await _api.get('/v1/guardian/devices/${Uri.encodeComponent(deviceId)}/apps'),
    );
  }
}

final Provider<AppsRepository> appsRepositoryProvider = Provider<AppsRepository>(
  (Ref ref) => AppsRepository(ref.watch(apiClientProvider)),
);

/// As falhas aparecem na tela com a acao de tentar de novo. Repetir sozinho esconderia o
/// erro e nao ajuda em respostas como "sem permissao".
Duration? noRetry(int retryCount, Object error) => null;

/// Apps de um aparelho. Recarrega quando o aparelho sincroniza de novo, para os tempos de
/// uso acompanharem o painel.
final FutureProviderFamily<DeviceApps, String> deviceAppsProvider = FutureProvider.autoDispose
    .family<DeviceApps, String>((Ref ref, String deviceId) {
      // Observa so o instante da ultima sincronizacao desse aparelho.
      ref.watch(
        devicesProvider.select((AsyncValue<List<Device>> devices) {
          final List<Device> list = devices.value ?? const <Device>[];
          for (final Device device in list) {
            if (device.id == deviceId) {
              return device.lastSyncAt;
            }
          }
          return null;
        }),
      );
      return ref.watch(appsRepositoryProvider).listApps(deviceId);
    }, retry: noRetry);
