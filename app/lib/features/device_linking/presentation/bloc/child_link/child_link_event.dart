part of 'child_link_bloc.dart';

sealed class ChildLinkEvent extends Equatable {
  const ChildLinkEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Passa a acompanhar a situacao do vinculo. Disparado uma vez, na criacao.
final class ChildLinkSubscriptionRequested extends ChildLinkEvent {
  const ChildLinkSubscriptionRequested();
}

/// Pergunta ao agente nativo se o aparelho esta vinculado (tela de entrada do modo crianca e
/// "Tentar de novo").
final class ChildLinkLoadRequested extends ChildLinkEvent {
  const ChildLinkLoadRequested();
}
