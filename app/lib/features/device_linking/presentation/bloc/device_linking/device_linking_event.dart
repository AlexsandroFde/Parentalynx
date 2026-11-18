part of 'device_linking_bloc.dart';

sealed class DeviceLinkingEvent extends Equatable {
  const DeviceLinkingEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu: consulta o servidor e passa a reagir aos avisos de pedido de vinculo.
final class DeviceLinkingStarted extends DeviceLinkingEvent {
  const DeviceLinkingStarted();
}

/// Consultar os pedidos e a situacao do codigo. A tela pede a cada poucos segundos, como
/// reserva para o caso de o aviso em tempo real nao chegar.
final class LinkRequestsCheckRequested extends DeviceLinkingEvent {
  const LinkRequestsCheckRequested();
}

/// Passou um segundo: atualiza a contagem regressiva e tira da tela o codigo vencido.
final class LinkCodeTicked extends DeviceLinkingEvent {
  const LinkCodeTicked();
}

/// A pessoa pediu um codigo novo.
final class LinkCodeRequested extends DeviceLinkingEvent {
  const LinkCodeRequested();
}

/// A pessoa confirmou o cancelamento do codigo mostrado.
final class LinkCodeCancelRequested extends DeviceLinkingEvent {
  const LinkCodeCancelRequested();
}

/// A pessoa aprovou o pedido dando nome a crianca.
final class LinkApprovalSubmitted extends DeviceLinkingEvent {
  const LinkApprovalSubmitted({required this.requestId, required this.childName});

  final String requestId;
  final String childName;

  @override
  List<Object?> get props => <Object?>[requestId, childName];
}

/// A pessoa confirmou a rejeicao do pedido.
final class LinkRejectionSubmitted extends DeviceLinkingEvent {
  const LinkRejectionSubmitted(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => <Object?>[requestId];
}

/// A pessoa saiu da tela de sucesso (concluir ou vincular outro aparelho).
final class ApprovedLinkDismissed extends DeviceLinkingEvent {
  const ApprovedLinkDismissed();
}
