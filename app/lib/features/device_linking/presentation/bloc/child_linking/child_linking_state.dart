part of 'child_linking_bloc.dart';

/// O que o formulario do codigo esta fazendo.
enum LinkFormActivity {
  /// Esperando a pessoa.
  idle,

  /// Conferindo se ha um pedido em andamento guardado.
  restoring,

  /// Enviando o codigo.
  submitting,

  /// Voltando para a escolha de modo.
  leaving;

  bool get isBusy => this == LinkFormActivity.restoring || this == LinkFormActivity.submitting;
}

/// Estado do fluxo de vinculacao.
sealed class ChildLinkingState extends Equatable {
  const ChildLinkingState({this.suggestedDeviceName});

  /// Nome deste aparelho informado pelo sistema, para preencher o campo uma vez.
  final String? suggestedDeviceName;
}

/// Formulario do codigo.
final class ChildLinkingForm extends ChildLinkingState {
  const ChildLinkingForm({
    this.activity = LinkFormActivity.idle,
    this.error,
    this.leaveFailure,
    super.suggestedDeviceName,
  });

  final LinkFormActivity activity;

  /// Motivo da recusa do ultimo pedido (codigo errado, vencido, recusado...).
  final String? error;

  /// A volta para a escolha de modo falhou.
  final AppFailure? leaveFailure;

  @override
  List<Object?> get props => <Object?>[activity, error, leaveFailure, suggestedDeviceName];
}

/// Pedido enviado, aguardando o responsavel aprovar.
final class ChildLinkingWaiting extends ChildLinkingState {
  const ChildLinkingWaiting({
    required this.claim,
    this.connectionTrouble = false,
    super.suggestedDeviceName,
  });

  final PairingClaim claim;

  /// A ultima consulta ao servidor falhou. A espera continua.
  final bool connectionTrouble;

  @override
  List<Object?> get props => <Object?>[claim, connectionTrouble, suggestedDeviceName];
}

/// Aprovado: gravando as credenciais e ligando o controle.
final class ChildLinkingActivating extends ChildLinkingState {
  const ChildLinkingActivating({required this.claim, super.suggestedDeviceName});

  final PairingClaim claim;

  @override
  List<Object?> get props => <Object?>[claim, suggestedDeviceName];
}
