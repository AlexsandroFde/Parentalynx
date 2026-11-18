part of 'child_device_bloc.dart';

/// Resultado de uma acao que a tela precisa tratar alem do aviso (compartilhar, abrir a folha
/// do codigo).
sealed class ChildDeviceOutcome extends Equatable {
  const ChildDeviceOutcome();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Dados exportados, em JSON formatado, prontos para compartilhar como arquivo.
final class ChildDeviceExportReady extends ChildDeviceOutcome {
  const ChildDeviceExportReady(this.content);

  final String content;

  @override
  List<Object?> get props => <Object?>[content];
}

/// Segredo do codigo de acesso offline, para a folha calcular o codigo do momento.
final class ChildDeviceOfflineSecretReady extends ChildDeviceOutcome {
  const ChildDeviceOfflineSecretReady(this.secret);

  final String secret;

  @override
  List<Object?> get props => <Object?>[secret];
}

/// Detalhe de um aparelho visto pelo responsavel.
sealed class ChildDeviceState extends Equatable {
  const ChildDeviceState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A lista de aparelhos ainda nao chegou.
final class ChildDeviceLoading extends ChildDeviceState {
  const ChildDeviceLoading();
}

/// O aparelho nao esta na lista (apagado por outro responsavel, por exemplo).
final class ChildDeviceNotFound extends ChildDeviceState {
  const ChildDeviceNotFound();
}

/// O aparelho foi apagado nesta tela. A tela avisa e fecha.
final class ChildDeviceRemoved extends ChildDeviceState {
  const ChildDeviceRemoved();
}

/// Aparelho carregado.
final class ChildDeviceLoaded extends ChildDeviceState {
  const ChildDeviceLoaded({required this.device, this.action = const ActionIdle(), this.outcome});

  final ChildDevice device;

  /// Andamento da ultima acao. Enquanto roda, os botoes ficam desabilitados.
  final ActionStatus action;

  /// O que a acao concluida entregou para a tela tratar.
  final ChildDeviceOutcome? outcome;

  bool get busy => action.isRunning;

  ChildDeviceLoaded copyWith({
    ChildDevice? device,
    ActionStatus? action,
    ChildDeviceOutcome? outcome,
  }) {
    return ChildDeviceLoaded(
      device: device ?? this.device,
      action: action ?? this.action,
      outcome: outcome,
    );
  }

  @override
  List<Object?> get props => <Object?>[device, action, outcome];
}
