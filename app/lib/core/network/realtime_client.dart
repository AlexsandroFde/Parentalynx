import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../json/json_reader.dart';

/// Abre o canal. Trocado nos testes por um canal falso.
typedef RealtimeConnector = WebSocketChannel Function(Uri uri, Map<String, String> headers);

WebSocketChannel _defaultConnector(Uri uri, Map<String, String> headers) {
  return IOWebSocketChannel.connect(
    uri,
    headers: headers,
    pingInterval: const Duration(seconds: 30),
    connectTimeout: const Duration(seconds: 15),
  );
}

/// Canal de avisos em tempo real (secao 7 do protocolo).
///
/// O canal so avisa que algo mudou. O estado e sempre buscado pelas rotas HTTP, entao perder
/// uma mensagem nao causa inconsistencia. Reconecta sozinho com espera progressiva.
class RealtimeClient {
  RealtimeClient({
    required this._endpoint,
    required this._headers,
    this._connector = _defaultConnector,
  });

  final Uri Function() _endpoint;
  final Map<String, String> Function() _headers;
  final RealtimeConnector _connector;

  final StreamController<JsonMap> _messages = StreamController<JsonMap>.broadcast();
  final StreamController<bool> _connection = StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  // Cancelada em _closeChannel, chamada por stop().
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  Timer? _pingTimer;
  int _attempt = 0;
  bool _running = false;
  bool _connected = false;

  /// Mensagens recebidas do servidor, ja decodificadas.
  Stream<JsonMap> get messages => _messages.stream;

  /// Emite verdadeiro ao conectar e falso ao cair.
  Stream<bool> get connection => _connection.stream;

  bool get isConnected => _connected;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _attempt = 0;
    _open();
  }

  Future<void> stop() async {
    _running = false;
    _retryTimer?.cancel();
    _pingTimer?.cancel();
    await _closeChannel();
    _setConnected(false);
  }

  Future<void> dispose() async {
    await stop();
    await _messages.close();
    await _connection.close();
  }

  /// Converte o endereco HTTP do servidor no endereco WebSocket de [path].
  static Uri webSocketUri(String serverUrl, String path) {
    final Uri base = Uri.parse(serverUrl.trim());
    final String basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '$basePath$path');
  }

  void _open() {
    if (!_running) {
      return;
    }
    final WebSocketChannel channel;
    try {
      channel = _connector(_endpoint(), _headers());
    } on Object {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      _onData,
      onError: (Object _) => _onClosed(),
      onDone: _onClosed,
      cancelOnError: true,
    );
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _send('{"type":"ping"}'));
  }

  void _onData(Object? data) {
    if (data is! String) {
      return;
    }
    final JsonMap message;
    try {
      message = decodeJsonObject(data);
    } on JsonFormatException {
      return;
    }
    if (!_connected) {
      _attempt = 0;
      _setConnected(true);
    }
    if (message.strOrNull('type') == 'pong') {
      return;
    }
    _messages.add(message);
  }

  void _onClosed() {
    _pingTimer?.cancel();
    _subscription = null;
    _channel = null;
    _setConnected(false);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_running) {
      return;
    }
    _attempt += 1;
    final int seconds = math.min(30, 1 << math.min(_attempt, 5));
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), _open);
  }

  void _send(String text) {
    try {
      _channel?.sink.add(text);
    } on Object {
      // O canal caiu entre o temporizador e o envio. A reconexao cuida disso.
    }
  }

  Future<void> _closeChannel() async {
    final StreamSubscription<Object?>? subscription = _subscription;
    final WebSocketChannel? channel = _channel;
    _subscription = null;
    _channel = null;
    await subscription?.cancel();
    try {
      await channel?.sink.close();
    } on Object {
      // Fechar um canal ja encerrado nao e um erro relevante.
    }
  }

  void _setConnected(bool value) {
    if (_connected == value) {
      return;
    }
    _connected = value;
    if (!_connection.isClosed) {
      _connection.add(value);
    }
  }
}

/// Decodifica uma mensagem de texto do canal, para uso em testes.
String encodeRealtimeMessage(Map<String, Object?> message) => jsonEncode(message);
