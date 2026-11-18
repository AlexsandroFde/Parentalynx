import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef BackendHandler = FutureOr<http.Response> Function(http.Request request);

/// Servidor de mentira: uma tabela de respostas por metodo e caminho, sobre o MockClient.
class FakeBackend {
  final Map<String, BackendHandler> _handlers = <String, BackendHandler>{};
  final List<http.Request> requests = <http.Request>[];

  /// Registra a resposta de `METODO /caminho` (sem a query).
  void on(String method, String path, BackendHandler handler) {
    _handlers['$method $path'] = handler;
  }

  /// Registra uma resposta JSON fixa.
  void onJson(String method, String path, Object body, {int status = 200}) {
    on(method, path, (http.Request request) => jsonResponse(body, status: status));
  }

  /// Registra uma resposta de erro no formato do protocolo.
  void onError(
    String method,
    String path, {
    required int status,
    required String code,
    String message = 'Erro.',
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    onJson(method, path, <String, Object?>{
      'error': <String, Object?>{'code': code, 'message': message, 'details': details},
    }, status: status);
  }

  http.Client get client => MockClient((http.Request request) async {
    requests.add(request);
    final BackendHandler? handler = _handlers['${request.method} ${request.url.path}'];
    if (handler == null) {
      return jsonResponse(<String, Object?>{
        'error': <String, Object?>{'code': 'not_found', 'message': 'Rota sem resposta no teste.'},
      }, status: 404);
    }
    return handler(request);
  });

  /// Requisicoes recebidas para `METODO /caminho`.
  List<http.Request> calls(String method, String path) {
    return requests.where((http.Request r) => r.method == method && r.url.path == path).toList();
  }

  /// Corpo JSON da ultima requisicao para `METODO /caminho`.
  Map<String, Object?> lastBody(String method, String path) {
    return jsonDecode(calls(method, path).last.body) as Map<String, Object?>;
  }
}

http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

/// Resposta de erro no formato do protocolo.
http.Response errorResponse(int status, String code, {Map<String, Object?>? details}) {
  return jsonResponse(<String, Object?>{
    'error': <String, Object?>{'code': code, 'message': 'Erro $code.', 'details': ?details},
  }, status: status);
}
