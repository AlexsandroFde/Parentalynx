part of 'child_linking_bloc.dart';

sealed class ChildLinkingEvent extends Equatable {
  const ChildLinkingEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela do codigo abriu: sugere o nome do aparelho e retoma um pedido em andamento.
final class ChildLinkingStarted extends ChildLinkingEvent {
  const ChildLinkingStarted();
}

/// A pessoa tocou em "Vincular".
final class ChildLinkingCodeSubmitted extends ChildLinkingEvent {
  const ChildLinkingCodeSubmitted({required this.code, required this.deviceName});

  final String code;
  final String deviceName;

  @override
  List<Object?> get props => <Object?>[code, deviceName];
}

/// Consultar agora se o responsavel respondeu. O temporizador da espera dispara este evento.
final class ChildLinkingPollRequested extends ChildLinkingEvent {
  const ChildLinkingPollRequested();
}

/// A pessoa desistiu do pedido em andamento.
final class ChildLinkingWaitCancelled extends ChildLinkingEvent {
  const ChildLinkingWaitCancelled();
}

/// A pessoa voltou a digitar: a mensagem de erro some.
final class ChildLinkingErrorCleared extends ChildLinkingEvent {
  const ChildLinkingErrorCleared();
}

/// A pessoa quer voltar para a escolha de modo do aparelho.
final class ChildLinkingLeaveRequested extends ChildLinkingEvent {
  const ChildLinkingLeaveRequested();
}
