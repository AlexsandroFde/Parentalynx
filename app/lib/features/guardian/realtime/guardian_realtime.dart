import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/realtime_client.dart';

/// Aviso em tempo real recebido do servidor (protocolo, secao 7).
class GuardianRealtimeEvent {
  const GuardianRealtimeEvent({required this.type, required this.payload});

  factory GuardianRealtimeEvent.fromJson(JsonMap json) {
    return GuardianRealtimeEvent(type: json.strOrNull('type') ?? '', payload: json);
  }

  /// `hello`, `device_updated`, `alert`, `link_pending`, `link_resolved`, `policy_applied`,
  /// `time_request`.
  final String type;
  final JsonMap payload;

  String? get deviceId => payload.strOrNull('deviceId');

  /// Verdadeiro para avisos que mudam a lista ou o estado dos aparelhos.
  bool get affectsDevices {
    return type == 'device_updated' ||
        type == 'link_pending' ||
        type == 'link_resolved' ||
        type == 'policy_applied' ||
        type == 'time_request';
  }
}

/// Canal em tempo real do responsavel. Fica conectado enquanto houver sessao.
///
/// O canal so avisa que algo mudou: quem recebe o aviso recarrega o dado pela API.
final Provider<RealtimeClient?> guardianRealtimeClientProvider = Provider<RealtimeClient?>((
  Ref ref,
) {
  final String? token = ref.watch(sessionTokenProvider);
  final String serverUrl = ref.watch(serverUrlProvider);
  if (token == null || serverUrl.isEmpty) {
    return null;
  }
  final RealtimeClient client = RealtimeClient(
    endpoint: () => RealtimeClient.webSocketUri(serverUrl, '/v1/guardian/stream'),
    headers: () => <String, String>{'Authorization': 'Bearer $token'},
  )..start();
  ref.onDispose(client.dispose);
  return client;
});

/// Avisos do servidor para a sessao atual. Vazio quando nao ha sessao.
final StreamProvider<GuardianRealtimeEvent> guardianRealtimeEventsProvider =
    StreamProvider<GuardianRealtimeEvent>((Ref ref) {
      final RealtimeClient? client = ref.watch(guardianRealtimeClientProvider);
      if (client == null) {
        return const Stream<GuardianRealtimeEvent>.empty();
      }
      return client.messages.map(GuardianRealtimeEvent.fromJson);
    });

/// Verdadeiro enquanto o canal em tempo real esta conectado.
final StreamProvider<bool> guardianRealtimeConnectedProvider = StreamProvider<bool>((Ref ref) {
  final RealtimeClient? client = ref.watch(guardianRealtimeClientProvider);
  if (client == null) {
    return Stream<bool>.value(false);
  }
  final StreamController<bool> controller = StreamController<bool>();
  controller.add(client.isConnected);
  final StreamSubscription<bool> subscription = client.connection.listen(controller.add);
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});
