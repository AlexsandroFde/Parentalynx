part of 'server_config_bloc.dart';

sealed class ServerConfigEvent extends Equatable {
  const ServerConfigEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Passa a acompanhar o endereco em uso.
final class ServerConfigSubscriptionRequested extends ServerConfigEvent {
  const ServerConfigSubscriptionRequested();
}

/// A pessoa informou um novo endereco.
final class ServerAddressSubmitted extends ServerConfigEvent {
  const ServerAddressSubmitted(this.url);

  final String url;

  @override
  List<Object?> get props => <Object?>[url];
}
