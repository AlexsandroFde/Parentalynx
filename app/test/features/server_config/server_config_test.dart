import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/bloc/form_status.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/network/server_endpoint.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/server_config/domain/entities/server_address_policy.dart';
import 'package:parentalynx/features/server_config/domain/usecases/update_server_address.dart';
import 'package:parentalynx/features/server_config/presentation/bloc/server_config_bloc.dart';

import '../../support/fake_backend.dart';
import '../../support/test_dependencies.dart';

void main() {
  group('ServerAddressPolicy', () {
    test('producao so aceita https', () {
      const ServerAddressPolicy release = ServerAddressPolicy(allowInsecureHttp: false);
      expect(release.accepts('https://controle.exemplo.com'), isTrue);
      expect(release.accepts('http://192.168.0.10:8080'), isFalse);
      expect(release.accepts('controle.exemplo.com'), isFalse);
      expect(release.accepts(''), isFalse);
      expect(release.requirementMessage, contains('https://'));
    });

    test('depuracao aceita http para rede local', () {
      const ServerAddressPolicy debug = ServerAddressPolicy(allowInsecureHttp: true);
      expect(debug.accepts('http://10.0.2.2:8080'), isTrue);
      expect(debug.accepts('ftp://exemplo.com'), isFalse);
    });
  });

  group('UpdateServerAddress', () {
    late FakeBackend backend;
    late TestDependencies deps;

    setUp(() {
      backend = FakeBackend();
      deps = TestDependencies(backend: backend, serverUrl: 'https://antigo.teste');
      addTearDown(deps.dispose);
    });

    test('grava o endereco sem barra final quando ha servidor respondendo', () async {
      backend.onJson('GET', '/v1/meta', <String, Object?>{'name': 'ParentaLynx'});

      final Result<void> result = await deps.di<UpdateServerAddress>()('https://novo.teste/');

      expect(result.isOk, isTrue);
      expect(deps.di<ServerEndpoint>().url, 'https://novo.teste');
      expect(deps.secureStore.values[StorageKeys.serverUrl], 'https://novo.teste');
      expect(backend.requests.single.url.toString(), 'https://novo.teste/v1/meta');
    });

    test('sem servidor no endereco volta ao anterior', () async {
      backend.onError('GET', '/v1/meta', status: 404, code: 'not_found');

      final Result<void> result = await deps.di<UpdateServerAddress>()('https://errado.teste');

      expect(result.failureOrNull, isA<ApiFailure>());
      expect(deps.di<ServerEndpoint>().url, 'https://antigo.teste');
    });

    test('endereco fora da regra nem e consultado', () async {
      final Result<void> result = await deps.di<UpdateServerAddress>()('sem-esquema');

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(backend.requests, isEmpty);
    });
  });

  group('ServerConfigBloc', () {
    late FakeBackend backend;
    late TestDependencies deps;

    setUp(() {
      backend = FakeBackend();
      deps = TestDependencies(backend: backend, serverUrl: '');
      addTearDown(deps.dispose);
    });

    test('estado inicial diz se o servidor ja esta configurado', () {
      final ServerConfigBloc bloc = deps.di<ServerConfigBloc>();
      addTearDown(bloc.close);
      expect(bloc.state.isConfigured, isFalse);
      expect(bloc.state.address, '');
    });

    blocTest<ServerConfigBloc, ServerConfigState>(
      'falha de conexao explica o motivo e mantem o formulario',
      setUp: () => backend.onError('GET', '/v1/meta', status: 500, code: 'internal'),
      build: () => deps.di<ServerConfigBloc>(),
      act: (ServerConfigBloc bloc) => bloc.add(const ServerAddressSubmitted('https://x.teste')),
      wait: const Duration(milliseconds: 10),
      verify: (ServerConfigBloc bloc) {
        expect(bloc.state.status, FormStatus.editing);
        expect(
          bloc.state.error,
          startsWith('Não foi possível falar com o servidor nesse endereço.'),
        );
        expect(bloc.state.isConfigured, isFalse);
      },
    );

    blocTest<ServerConfigBloc, ServerConfigState>(
      'endereco aceito marca o servidor como configurado',
      setUp: () => backend.onJson('GET', '/v1/meta', <String, Object?>{}),
      build: () => deps.di<ServerConfigBloc>(),
      act: (ServerConfigBloc bloc) => bloc.add(const ServerAddressSubmitted('https://ok.teste')),
      wait: const Duration(milliseconds: 10),
      verify: (ServerConfigBloc bloc) {
        expect(bloc.state.status, FormStatus.succeeded);
        expect(bloc.state.isConfigured, isTrue);
        expect(bloc.state.address, 'https://ok.teste');
      },
    );
  });
}
