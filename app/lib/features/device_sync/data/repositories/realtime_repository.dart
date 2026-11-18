import 'dart:async';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/realtime_client.dart';
import '../../../../core/network/server_endpoint.dart';
import '../../../../core/network/session_credentials.dart';
import '../../../../core/utils/observable_value.dart';
import '../../domain/entities/realtime_update.dart';
import '../../domain/repositories/i_realtime_repository.dart';
import '../mappers/realtime_update_mapper.dart';

/// Canal em tempo real do responsavel sobre WebSocket (`/v1/guardian/stream`).
///
/// O token e lido a cada reconexao, entao uma sessao renovada continua valendo.
class RealtimeRepository implements IRealtimeRepository {
  RealtimeRepository({required this._endpoint, required this._credentials, this._connector});

  final ServerEndpoint _endpoint;
  final SessionCredentials _credentials;
  final RealtimeConnector? _connector;

  final StreamController<RealtimeUpdate> _updates = StreamController<RealtimeUpdate>.broadcast();
  final ObservableValue<bool> _connected = ObservableValue<bool>.seeded(false);

  RealtimeClient? _client;
  StreamSubscription<JsonMap>? _messages;
  StreamSubscription<bool>? _connection;

  @override
  Stream<RealtimeUpdate> get updates => _updates.stream;

  @override
  Stream<bool> watchConnection() => _connected.stream;

  @override
  void connect() {
    final String serverUrl = _endpoint.url;
    if (_client != null || !_credentials.hasToken || serverUrl.isEmpty) {
      return;
    }
    final RealtimeConnector? connector = _connector;
    final RealtimeClient client = connector == null
        ? RealtimeClient(endpoint: () => _uri(serverUrl), headers: _headers)
        : RealtimeClient(endpoint: () => _uri(serverUrl), headers: _headers, connector: connector);
    _messages = client.messages.listen(_onMessage);
    _connection = client.connection.listen(_connected.add);
    _client = client;
    client.start();
  }

  @override
  Future<void> disconnect() async {
    final RealtimeClient? client = _client;
    _client = null;
    await _messages?.cancel();
    await _connection?.cancel();
    _messages = null;
    _connection = null;
    await client?.dispose();
    _connected.add(false);
  }

  void _onMessage(JsonMap message) {
    final RealtimeUpdate? update = RealtimeUpdateMapper.fromJson(message);
    if (update != null && !_updates.isClosed) {
      _updates.add(update);
    }
  }

  static Uri _uri(String serverUrl) {
    return RealtimeClient.webSocketUri(serverUrl, '/v1/guardian/stream');
  }

  Map<String, String> _headers() {
    final String? token = _credentials.token;
    return <String, String>{if (token != null) 'Authorization': 'Bearer $token'};
  }
}
