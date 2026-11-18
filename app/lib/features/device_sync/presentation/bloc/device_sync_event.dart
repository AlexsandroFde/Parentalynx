part of 'device_sync_bloc.dart';

sealed class DeviceSyncEvent extends Equatable {
  const DeviceSyncEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O painel abriu: abre o canal em tempo real e acompanha a conexao.
final class DeviceSyncStarted extends DeviceSyncEvent {
  const DeviceSyncStarted();
}
