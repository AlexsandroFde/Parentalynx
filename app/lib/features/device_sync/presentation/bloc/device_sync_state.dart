part of 'device_sync_bloc.dart';

/// Estado do canal de atualizacoes em tempo real do painel.
sealed class DeviceSyncState extends Equatable {
  const DeviceSyncState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O canal ainda nao foi aberto.
final class DeviceSyncIdle extends DeviceSyncState {
  const DeviceSyncIdle();
}

/// Abrindo o canal (primeira conexao).
final class DeviceSyncConnecting extends DeviceSyncState {
  const DeviceSyncConnecting();
}

/// Conectado: mudancas nos aparelhos chegam na hora.
final class DeviceSyncOnline extends DeviceSyncState {
  const DeviceSyncOnline();
}

/// Sem conexao. O canal tenta de novo sozinho; os dados continuam vindo pelas rotas HTTP.
final class DeviceSyncOffline extends DeviceSyncState {
  const DeviceSyncOffline();
}
