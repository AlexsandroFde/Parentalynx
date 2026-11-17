import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/network/api_client.dart';

void main() {
  ApiClient clientWith(
    MockClientHandler handler, {
    String baseUrl = 'https://servidor.teste',
    String? token = 'gs_abc',
    void Function()? onSessionInvalid,
  }) {
    return ApiClient(
      httpClient: MockClient(handler),
      baseUrl: () => baseUrl,
      sessionToken: () => token,
      onSessionInvalid: onSessionInvalid,
    );
  }

  http.Response jsonResponse(Object body, [int status = 200]) {
    return http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
    );
  }

  test('envia o token da sessao e decodifica a resposta', () async {
    late http.Request seen;
    final ApiClient client = clientWith((http.Request request) async {
      seen = request;
      return jsonResponse(<String, Object?>{'ok': true, 'nome': 'João'});
    });

    final JsonMap result = await client.get(
      '/v1/guardian/me',
      query: <String, String?>{'a': '1', 'vazio': null},
    );

    expect(seen.method, 'GET');
    expect(seen.url.toString(), 'https://servidor.teste/v1/guardian/me?a=1');
    expect(seen.headers['Authorization'], 'Bearer gs_abc');
    expect(result.str('nome'), 'João');
  });

  test('chamada publica nao envia o token', () async {
    late http.Request seen;
    final ApiClient client = clientWith((http.Request request) async {
      seen = request;
      return jsonResponse(<String, Object?>{});
    });

    await client.post(
      '/v1/auth/login',
      body: <String, Object?>{'email': 'a@b.c'},
      auth: ApiAuth.none,
    );

    expect(seen.headers.containsKey('Authorization'), isFalse);
    expect(seen.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), <String, Object?>{'email': 'a@b.c'});
  });

  test('token explicito substitui o da sessao', () async {
    late http.Request seen;
    final ApiClient client = clientWith((http.Request request) async {
      seen = request;
      return jsonResponse(<String, Object?>{'status': 'pending'});
    });

    await client.get('/v1/pairing/status', bearer: 'pp_xyz');

    expect(seen.headers['Authorization'], 'Bearer pp_xyz');
  });

  test('respeita um prefixo de caminho no endereco do servidor', () async {
    late http.Request seen;
    final ApiClient client = clientWith((http.Request request) async {
      seen = request;
      return jsonResponse(<String, Object?>{});
    }, baseUrl: 'https://exemplo.com/plx/');

    await client.get('/v1/meta', auth: ApiAuth.none);

    expect(seen.url.toString(), 'https://exemplo.com/plx/v1/meta');
  });

  test('resposta 204 vira objeto vazio', () async {
    final ApiClient client = clientWith((http.Request request) async => http.Response('', 204));
    final JsonMap result = await client.post('/v1/auth/logout');
    expect(result.raw, isEmpty);
  });

  test('erro do protocolo vira ApiFailure com codigo e detalhes', () async {
    final ApiClient client = clientWith((http.Request request) async {
      return jsonResponse(<String, Object?>{
        'error': <String, Object?>{
          'code': 'account_locked',
          'message': 'Muitas tentativas.',
          'details': <String, Object?>{'retryAfterSec': 60},
        },
      }, 423);
    });

    await expectLater(
      client.post('/v1/auth/login', auth: ApiAuth.none),
      throwsA(
        isA<ApiFailure>()
            .having((ApiFailure f) => f.code, 'code', 'account_locked')
            .having((ApiFailure f) => f.status, 'status', 423)
            .having((ApiFailure f) => f.message, 'message', 'Muitas tentativas.')
            .having((ApiFailure f) => f.retryAfterSec, 'retryAfterSec', 60)
            .having((ApiFailure f) => f.isLocked, 'isLocked', isTrue),
      ),
    );
  });

  test('sessao recusada avisa quem cuida da sessao', () async {
    int invalidated = 0;
    final ApiClient client = clientWith((http.Request request) async {
      return jsonResponse(<String, Object?>{
        'error': <String, Object?>{'code': 'session_expired', 'message': 'Sessão expirada.'},
      }, 401);
    }, onSessionInvalid: () => invalidated += 1);

    await expectLater(client.get('/v1/guardian/me'), throwsA(isA<ApiFailure>()));
    expect(invalidated, 1);

    // Um token explicito recusado (vinculacao) nao derruba a sessao do responsavel.
    await expectLater(client.get('/v1/pairing/status', bearer: 'pp_x'), throwsA(isA<ApiFailure>()));
    expect(invalidated, 1);
  });

  test('erro sem corpo JSON vira ApiFailure generico', () async {
    final ApiClient client = clientWith(
      (http.Request request) async => http.Response('<html>502</html>', 502),
    );
    await expectLater(
      client.get('/v1/meta'),
      throwsA(isA<ApiFailure>().having((ApiFailure f) => f.code, 'code', 'internal')),
    );
  });

  test('falha de rede vira NetworkFailure', () async {
    final ApiClient client = clientWith((http.Request request) async {
      throw const SocketException('sem rede');
    });
    await expectLater(client.get('/v1/meta'), throwsA(isA<NetworkFailure>()));
  });

  test('corpo de sucesso que nao e JSON vira UnexpectedFailure', () async {
    final ApiClient client = clientWith(
      (http.Request request) async => http.Response('nao e json', 200),
    );
    await expectLater(client.get('/v1/meta'), throwsA(isA<UnexpectedFailure>()));
  });

  test('servidor nao configurado', () async {
    final ApiClient client = clientWith(
      (http.Request request) async => jsonResponse(<String, Object?>{}),
      baseUrl: '',
    );
    expect(() => client.resolve('/v1/meta'), throwsA(isA<UnexpectedFailure>()));
  });
}
