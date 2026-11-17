import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../realtime/guardian_realtime.dart';
import '../data/devices_repository.dart';
import '../domain/device.dart';

/// Lista de aparelhos da conta (pendentes, ativos e revogados).
///
/// Recarrega sozinha quando chega um aviso em tempo real que afeta aparelhos. Use
/// `ref.read(devicesProvider.notifier).refresh()` depois de uma acao que muda a lista.
final AsyncNotifierProvider<DevicesController, List<Device>> devicesProvider =
    AsyncNotifierProvider<DevicesController, List<Device>>(DevicesController.new);

class DevicesController extends AsyncNotifier<List<Device>> {
  Timer? _debounce;

  @override
  Future<List<Device>> build() async {
    ref.listen<AsyncValue<GuardianRealtimeEvent>>(guardianRealtimeEventsProvider, (
      AsyncValue<GuardianRealtimeEvent>? previous,
      AsyncValue<GuardianRealtimeEvent> next,
    ) {
      final GuardianRealtimeEvent? event = next.value;
      if (event != null && event.affectsDevices) {
        _scheduleRefresh();
      }
    });
    ref.onDispose(() => _debounce?.cancel());
    return ref.watch(devicesRepositoryProvider).listDevices();
  }

  /// Recarrega mantendo a lista atual na tela enquanto a nova nao chega.
  Future<void> refresh() async {
    final AsyncValue<List<Device>> result = await AsyncValue.guard(
      () => ref.read(devicesRepositoryProvider).listDevices(),
    );
    if (!ref.mounted) {
      return;
    }
    if (result.hasError && state.hasValue) {
      // Mantem os dados antigos se a atualizacao em segundo plano falhar.
      return;
    }
    state = result;
  }

  /// Substitui um aparelho na lista sem ir ao servidor (depois de aprovar ou renomear).
  void replace(Device device) {
    final List<Device>? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<List<Device>>(<Device>[
      for (final Device item in current)
        if (item.id == device.id) device else item,
    ]);
  }

  void _scheduleRefresh() {
    // Varios avisos seguidos viram uma unica recarga.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(refresh()));
  }
}

/// Aparelhos ativos, na ordem de aprovacao.
final Provider<List<Device>> activeDevicesProvider = Provider<List<Device>>((Ref ref) {
  final List<Device> all = ref.watch(devicesProvider).value ?? const <Device>[];
  return all.where((Device device) => device.status == DeviceStatus.active).toList();
});

/// Vinculos aguardando a aprovacao do responsavel.
final Provider<List<Device>> pendingDevicesProvider = Provider<List<Device>>((Ref ref) {
  final List<Device> all = ref.watch(devicesProvider).value ?? const <Device>[];
  return all.where((Device device) => device.status == DeviceStatus.pending).toList();
});

/// Identificador do aparelho escolhido no painel. Nulo usa o primeiro aparelho ativo.
final NotifierProvider<SelectedDeviceIdController, String?> selectedDeviceIdProvider =
    NotifierProvider<SelectedDeviceIdController, String?>(SelectedDeviceIdController.new);

class SelectedDeviceIdController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? deviceId) {
    state = deviceId;
  }
}

/// Aparelho em foco no painel, nas regras e nos relatorios. Nulo quando nao ha aparelho ativo.
final Provider<Device?> selectedDeviceProvider = Provider<Device?>((Ref ref) {
  final List<Device> active = ref.watch(activeDevicesProvider);
  final String? selectedId = ref.watch(selectedDeviceIdProvider);
  return active.firstWhereOrNull((Device device) => device.id == selectedId) ?? active.firstOrNull;
});
