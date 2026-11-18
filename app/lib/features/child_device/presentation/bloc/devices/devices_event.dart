part of 'devices_bloc.dart';

sealed class DevicesEvent extends Equatable {
  const DevicesEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O painel abriu: carrega a lista, acompanha as mudancas e os avisos em tempo real.
final class DevicesStarted extends DevicesEvent {
  const DevicesStarted();
}

/// Recarregar a lista (puxar para atualizar, tentar de novo).
///
/// [completer] e concluido quando a recarga termina, para o indicador de atualizacao da tela
/// saber quando sumir. Nao entra na comparacao do evento.
final class DevicesRefreshRequested extends DevicesEvent {
  const DevicesRefreshRequested({this.completer});

  final Completer<void>? completer;
}

/// Chegou um aviso em tempo real que muda aparelhos. Varios avisos seguidos viram uma recarga.
final class DevicesRealtimeChanged extends DevicesEvent {
  const DevicesRealtimeChanged();
}

/// O responsavel escolheu o aparelho em foco no painel, nas regras e nos relatorios.
final class DeviceSelected extends DevicesEvent {
  const DeviceSelected(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}
