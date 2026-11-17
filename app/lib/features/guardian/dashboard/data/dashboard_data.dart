import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/network_providers.dart';
import '../../apps/data/apps_repository.dart' show noRetry;
import '../../devices/data/devices_repository.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../realtime/guardian_realtime.dart';

/// Alerta resumido para a previa do painel.
class AlertPreview {
  const AlertPreview({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.childName,
  });

  factory AlertPreview.fromJson(JsonMap json) {
    return AlertPreview(
      id: json.intOr('id', fallback: 0),
      type: json.strOrNull('type') ?? '',
      title: json.strOrNull('title') ?? '',
      body: json.strOrNull('body') ?? '',
      createdAt: json.intOr('createdAt', fallback: 0),
      read: json.has('readAt'),
      childName: json.strOrNull('childName'),
    );
  }

  final int id;
  final String type;
  final String title;
  final String body;
  final int createdAt;
  final bool read;
  final String? childName;
}

/// Os tres alertas mais recentes da conta. Recarrega quando chega um alerta em tempo real.
final FutureProvider<List<AlertPreview>> recentAlertsProvider =
    FutureProvider.autoDispose<List<AlertPreview>>((Ref ref) async {
      ref.listen<AsyncValue<GuardianRealtimeEvent>>(guardianRealtimeEventsProvider, (
        AsyncValue<GuardianRealtimeEvent>? previous,
        AsyncValue<GuardianRealtimeEvent> next,
      ) {
        if (next.value?.type == 'alert') {
          ref.invalidateSelf();
        }
      });
      final JsonMap json = await ref
          .watch(apiClientProvider)
          .get('/v1/guardian/alerts', query: <String, String?>{'limit': '3'});
      return json.objList('alerts').map(AlertPreview.fromJson).toList();
    }, retry: noRetry);

/// Politica em vigor de um aparelho, para o painel saber dos comandos ativos (tempo extra,
/// pausa, suspensao). Acompanha a versao do servidor.
final AsyncNotifierProviderFamily<DevicePolicySnapshot, DevicePolicy, String>
devicePolicySnapshotProvider =
    AsyncNotifierProvider.family<DevicePolicySnapshot, DevicePolicy, String>(
      DevicePolicySnapshot.new,
      retry: noRetry,
    );

class DevicePolicySnapshot extends AsyncNotifier<DevicePolicy> {
  DevicePolicySnapshot(this.deviceId);

  final String deviceId;
  bool _loading = false;

  @override
  Future<DevicePolicy> build() async {
    ref.listen<AsyncValue<List<Device>>>(devicesProvider, (
      AsyncValue<List<Device>>? previous,
      AsyncValue<List<Device>> next,
    ) {
      final Device? device = next.value?.firstWhereOrNull((Device item) => item.id == deviceId);
      final DevicePolicy? current = state.value;
      if (device != null && current != null && device.policyVersion > current.version) {
        unawaited(_reload());
      }
    });
    return (await ref.read(devicesRepositoryProvider).getDevice(deviceId)).policy;
  }

  /// Adota a politica devolvida por um comando, sem ir de novo ao servidor.
  void set(DevicePolicy policy) {
    state = AsyncData<DevicePolicy>(policy);
  }

  Future<void> _reload() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      final DevicePolicy latest = (await ref.read(devicesRepositoryProvider).getDevice(deviceId))
          .policy;
      if (ref.mounted && latest.version >= (state.value?.version ?? 0)) {
        state = AsyncData<DevicePolicy>(latest);
      }
    } on Object {
      // Mantem a ultima politica conhecida se a atualizacao em segundo plano falhar.
    } finally {
      _loading = false;
    }
  }
}
