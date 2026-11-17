import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/network/realtime_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Canal falso: o teste controla o que chega do "servidor" e ve o que o cliente envia.
class _FakeChannel implements WebSocketChannel {
  // Duble de teste: o controlador vive so durante o teste.
  // ignore: close_sinks
  final StreamController<Object?> incoming = StreamController<Object?>();
  // ignore: close_sinks
  final _FakeSink outgoing = _FakeSink();

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  WebSocketSink get sink => outgoing;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  final List<Object?> sent = <Object?>[];
  bool closed = false;
  final Completer<void> _done = Completer<void>();

  @override
  void add(Object? data) => sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Object?> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;
}

void main() {
  test('converte o endereco HTTP do servidor em endereco WebSocket', () {
    expect(
      RealtimeClient.webSocketUri('https://exemplo.com', '/v1/guardian/stream').toString(),
      'wss://exemplo.com/v1/guardian/stream',
    );
    expect(
      RealtimeClient.webSocketUri('http://10.0.2.2:8080/', '/v1/device/stream').toString(),
      'ws://10.0.2.2:8080/v1/device/stream',
    );
    expect(
      RealtimeClient.webSocketUri('https://exemplo.com/plx', '/v1/guardian/stream').toString(),
      'wss://exemplo.com/plx/v1/guardian/stream',
    );
  });

  testWidgets('entrega as mensagens, ignora pong e marca a conexao', (WidgetTester tester) async {
    final _FakeChannel channel = _FakeChannel();
    late Uri seenUri;
    late Map<String, String> seenHeaders;
    final RealtimeClient client = RealtimeClient(
      endpoint: () => Uri.parse('wss://exemplo.com/v1/guardian/stream'),
      headers: () => <String, String>{'Authorization': 'Bearer gs_abc'},
      connector: (Uri uri, Map<String, String> headers) {
        seenUri = uri;
        seenHeaders = headers;
        return channel;
      },
    );
    final List<JsonMap> received = <JsonMap>[];
    final List<bool> connection = <bool>[];
    final StreamSubscription<JsonMap> messages = client.messages.listen(received.add);
    final StreamSubscription<bool> states = client.connection.listen(connection.add);

    client.start();
    expect(seenUri.toString(), 'wss://exemplo.com/v1/guardian/stream');
    expect(seenHeaders['Authorization'], 'Bearer gs_abc');
    expect(client.isConnected, isFalse);

    channel.incoming.add('{"type":"hello","serverTime":1}');
    channel.incoming.add('{"type":"pong"}');
    channel.incoming.add('texto que nao e json');
    channel.incoming.add('{"type":"device_updated","deviceId":"d1"}');
    await tester.pump();

    expect(client.isConnected, isTrue);
    expect(connection, <bool>[true]);
    expect(received.map((JsonMap m) => m.str('type')), <String>['hello', 'device_updated']);

    // O cliente envia ping a cada 30 segundos.
    await tester.pump(const Duration(seconds: 31));
    expect(channel.outgoing.sent, contains('{"type":"ping"}'));

    // Cancelar assinaturas devolve um futuro da zona raiz, que nao avanca no tempo simulado
    // dos testes de widget. Por isso o encerramento roda em tempo real.
    await tester.runAsync(client.stop);
    expect(channel.outgoing.closed, isTrue);
    expect(client.isConnected, isFalse);

    await tester.runAsync(() async {
      await messages.cancel();
      await states.cancel();
      await client.dispose();
    });
  });

  testWidgets('reconecta com espera progressiva quando o canal cai', (WidgetTester tester) async {
    final List<_FakeChannel> channels = <_FakeChannel>[];
    final RealtimeClient client = RealtimeClient(
      endpoint: () => Uri.parse('wss://exemplo.com/v1/guardian/stream'),
      headers: () => const <String, String>{},
      connector: (Uri uri, Map<String, String> headers) {
        final _FakeChannel channel = _FakeChannel();
        channels.add(channel);
        return channel;
      },
    );

    client.start();
    expect(channels, hasLength(1));
    channels[0].incoming.add('{"type":"hello"}');
    await tester.pump();
    expect(client.isConnected, isTrue);

    // O servidor fecha a conexao.
    await channels[0].incoming.close();
    await tester.pump();
    expect(client.isConnected, isFalse);

    // Primeira nova tentativa depois de 2 segundos.
    await tester.pump(const Duration(seconds: 1));
    expect(channels, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(channels, hasLength(2));

    // Cai de novo sem ter conectado: a espera dobra para 4 segundos.
    await channels[1].incoming.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(channels, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(channels, hasLength(3));

    await tester.runAsync(client.dispose);
    await tester.pump(const Duration(seconds: 60));
    expect(channels, hasLength(3), reason: 'depois de parar nao tenta mais');
  });

  testWidgets('falha ao abrir o canal agenda nova tentativa', (WidgetTester tester) async {
    int attempts = 0;
    final RealtimeClient client = RealtimeClient(
      endpoint: () => Uri.parse('wss://exemplo.com/v1/guardian/stream'),
      headers: () => const <String, String>{},
      connector: (Uri uri, Map<String, String> headers) {
        attempts += 1;
        throw StateError('sem rede');
      },
    );

    client.start();
    expect(attempts, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(attempts, 2);

    await tester.runAsync(client.dispose);
  });
}
