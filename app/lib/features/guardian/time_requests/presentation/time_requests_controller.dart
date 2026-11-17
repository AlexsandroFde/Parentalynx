import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../realtime/guardian_realtime.dart';
import '../data/api_time_requests_repository.dart';
import '../domain/time_request.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// Pedidos de tempo de todos os aparelhos ativos, do mais novo para o mais antigo.
///
/// Recarrega quando a lista de aparelhos ativos muda e quando chega um aviso de novo pedido.
final AsyncNotifierProvider<TimeRequestsController, List<TimeRequest>> timeRequestsProvider =
    AsyncNotifierProvider<TimeRequestsController, List<TimeRequest>>(
      TimeRequestsController.new,
      retry: _noRetry,
    );

class TimeRequestsController extends AsyncNotifier<List<TimeRequest>> {
  @override
  Future<List<TimeRequest>> build() async {
    // Observa so os identificadores, para nao recarregar a cada sincronizacao dos aparelhos.
    final String deviceIds = ref.watch(
      activeDevicesProvider.select(
        (List<Device> devices) => devices.map((Device device) => device.id).join(','),
      ),
    );
    ref.listen<AsyncValue<GuardianRealtimeEvent>>(guardianRealtimeEventsProvider, (
      AsyncValue<GuardianRealtimeEvent>? previous,
      AsyncValue<GuardianRealtimeEvent> next,
    ) {
      if (next.value?.type == 'time_request') {
        refresh();
      }
    });
    return _load(deviceIds.isEmpty ? const <String>[] : deviceIds.split(','));
  }

  Future<List<TimeRequest>> _load(List<String> deviceIds) async {
    final List<List<TimeRequest>> perDevice = await Future.wait(<Future<List<TimeRequest>>>[
      for (final String deviceId in deviceIds)
        ref.read(timeRequestsRepositoryProvider).list(deviceId),
    ]);
    final List<TimeRequest> all = perDevice.expand((List<TimeRequest> list) => list).toList()
      ..sort((TimeRequest a, TimeRequest b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// Recarrega mantendo a lista atual na tela enquanto a nova nao chega.
  Future<void> refresh() async {
    final List<String> deviceIds = ref
        .read(activeDevicesProvider)
        .map((Device device) => device.id)
        .toList();
    final AsyncValue<List<TimeRequest>> result = await AsyncValue.guard(() => _load(deviceIds));
    if (!ref.mounted) {
      return;
    }
    if (result.hasError && state.hasValue) {
      return;
    }
    state = result;
  }

  /// (E) Aprova ou nega um pedido e atualiza a lista e a contagem dos aparelhos.
  Future<TimeRequest> resolve(String requestId, {required bool approve, int? minutes}) async {
    final TimeRequest resolved = await ref
        .read(timeRequestsRepositoryProvider)
        .resolve(requestId, approve: approve, minutes: minutes);
    if (ref.mounted) {
      final List<TimeRequest>? current = state.value;
      if (current != null) {
        state = AsyncData<List<TimeRequest>>(<TimeRequest>[
          for (final TimeRequest item in current)
            if (item.id == requestId) resolved else item,
        ]);
      }
      await ref.read(devicesProvider.notifier).refresh();
    }
    return resolved;
  }
}

/// Quantidade de pedidos de tempo aguardando resposta, somando os aparelhos ativos.
final Provider<int> pendingTimeRequestsCountProvider = Provider<int>((Ref ref) {
  return ref
      .watch(activeDevicesProvider)
      .fold<int>(0, (int total, Device device) => total + device.pendingTimeRequests);
});
