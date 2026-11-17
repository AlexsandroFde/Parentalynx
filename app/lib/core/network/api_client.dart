import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';
import '../json/json_reader.dart';

/// Como autenticar uma chamada.
enum ApiAuth {
  /// Usa o token da sessao do responsavel, se houver.
  session,

  /// Chamada publica ou com token informado em `bearer`.
  none,
}

/// Cliente HTTP da API do ParentaLynx.
///
/// Converte toda resposta de erro e toda falha de rede em [AppFailure]. Nao guarda estado: o
/// endereco do servidor e o token sao lidos a cada chamada pelos callbacks recebidos.
class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required this._baseUrl,
    required this._sessionToken,
    this._onSessionInvalid,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient;

  final http.Client _http;
  final String Function() _baseUrl;
  final String? Function() _sessionToken;
  final void Function()? _onSessionInvalid;
  final Duration timeout;

  Future<JsonMap> get(
    String path, {
    Map<String, String?>? query,
    ApiAuth auth = ApiAuth.session,
    String? bearer,
  }) {
    return _sendJson('GET', path, query: query, auth: auth, bearer: bearer);
  }

  Future<JsonMap> post(
    String path, {
    Map<String, Object?>? body,
    ApiAuth auth = ApiAuth.session,
    String? bearer,
  }) {
    return _sendJson('POST', path, body: body, auth: auth, bearer: bearer);
  }

  Future<JsonMap> put(String path, {Map<String, Object?>? body}) {
    return _sendJson('PUT', path, body: body);
  }

  Future<JsonMap> patch(String path, {Map<String, Object?>? body}) {
    return _sendJson('PATCH', path, body: body);
  }

  Future<JsonMap> delete(String path, {Map<String, Object?>? body}) {
    return _sendJson('DELETE', path, body: body);
  }

  /// Baixa um recurso binario autenticado (icones de apps).
  Future<Uint8List> getBytes(String path, {Map<String, String?>? query}) async {
    final http.Response response = await _send('GET', path, query: query, accept: '*/*');
    return response.bodyBytes;
  }

  /// Monta o endereco absoluto de um caminho da API.
  Uri resolve(String path, {Map<String, String?>? query}) {
    final String base = _baseUrl().trim();
    if (base.isEmpty) {
      throw const UnexpectedFailure('O endereço do servidor não foi configurado.');
    }
    final Uri baseUri = Uri.parse(base);
    final String basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final Map<String, String> cleanQuery = <String, String>{
      if (query != null)
        for (final MapEntry<String, String?> entry in query.entries)
          if (entry.value != null) entry.key: entry.value!,
    };
    return baseUri.replace(
      path: '$basePath$path',
      queryParameters: cleanQuery.isEmpty ? null : cleanQuery,
    );
  }

  /// Cabecalho de autorizacao da sessao atual, para quem precisa montar requisicoes proprias
  /// (imagens autenticadas, WebSocket).
  Map<String, String> sessionHeaders() {
    final String? token = _sessionToken();
    return <String, String>{if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<JsonMap> _sendJson(
    String method,
    String path, {
    Map<String, String?>? query,
    Map<String, Object?>? body,
    ApiAuth auth = ApiAuth.session,
    String? bearer,
  }) async {
    final http.Response response = await _send(
      method,
      path,
      query: query,
      body: body,
      auth: auth,
      bearer: bearer,
    );
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      return const JsonMap.empty();
    }
    try {
      return decodeJsonObject(utf8.decode(response.bodyBytes));
    } on JsonFormatException catch (error) {
      throw UnexpectedFailure('O servidor respondeu em um formato inesperado.', error);
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Map<String, Object?>? body,
    ApiAuth auth = ApiAuth.session,
    String? bearer,
    String accept = 'application/json',
  }) async {
    final Uri uri = resolve(path, query: query);
    final String? token = bearer ?? (auth == ApiAuth.session ? _sessionToken() : null);
    final http.Request request = http.Request(method, uri)
      ..headers['Accept'] = accept
      ..followRedirects = false;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }

    final http.Response response;
    try {
      final http.StreamedResponse streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const NetworkFailure('O servidor demorou para responder. Tente de novo.');
    } on SocketException {
      throw const NetworkFailure();
    } on HandshakeException {
      throw const NetworkFailure('Não foi possível estabelecer uma conexão segura com o servidor.');
    } on http.ClientException {
      throw const NetworkFailure();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    final ApiFailure failure = _parseFailure(response);
    if (failure.isSessionInvalid && bearer == null && auth == ApiAuth.session) {
      _onSessionInvalid?.call();
    }
    throw failure;
  }

  ApiFailure _parseFailure(http.Response response) {
    try {
      final JsonMap body = decodeJsonObject(utf8.decode(response.bodyBytes));
      final JsonMap error = body.obj('error');
      return ApiFailure(
        status: response.statusCode,
        code: error.str('code'),
        message: error.strOrNull('message') ?? 'Erro ${response.statusCode}.',
        details: error.objOrNull('details') ?? const JsonMap.empty(),
      );
    } on Object {
      return ApiFailure(
        status: response.statusCode,
        code: 'internal',
        message: 'O servidor respondeu com o erro ${response.statusCode}.',
      );
    }
  }
}
