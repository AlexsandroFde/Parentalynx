import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/network/server_endpoint.dart';
import 'data/repositories/server_config_repository.dart';
import 'domain/entities/server_address_policy.dart';
import 'domain/repositories/i_server_config_repository.dart';
import 'domain/usecases/update_server_address.dart';
import 'domain/usecases/watch_server_address.dart';
import 'presentation/bloc/server_config_bloc.dart';

/// Registra as dependencias do endereco do servidor.
///
/// [allowInsecureHttp] vem da configuracao do build: so builds de depuracao aceitam HTTP.
void registerServerConfigModule(GetIt di, {required bool allowInsecureHttp}) {
  di
    ..registerSingleton<ServerAddressPolicy>(
      ServerAddressPolicy(allowInsecureHttp: allowInsecureHttp),
    )
    ..registerLazySingleton<IServerConfigRepository>(
      () => ServerConfigRepository(endpoint: di<ServerEndpoint>(), api: di<ApiClient>()),
    )
    ..registerFactory<WatchServerAddress>(
      () => WatchServerAddress(
        repository: di<IServerConfigRepository>(),
        policy: di<ServerAddressPolicy>(),
      ),
    )
    ..registerFactory<UpdateServerAddress>(
      () => UpdateServerAddress(
        repository: di<IServerConfigRepository>(),
        policy: di<ServerAddressPolicy>(),
      ),
    )
    // Uma instancia por tela que mostra ou troca o endereco.
    ..registerFactory<ServerConfigBloc>(
      () => ServerConfigBloc(
        watchServerAddress: di<WatchServerAddress>(),
        updateServerAddress: di<UpdateServerAddress>(),
      )..add(const ServerConfigSubscriptionRequested()),
    );
}
