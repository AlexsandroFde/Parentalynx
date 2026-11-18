import '../entities/link_state.dart';

/// Situacao do vinculo deste aparelho.
///
/// E a fonte unica de verdade da fase do vinculo: os casos de uso a alteram (vincular,
/// concluir a configuracao, desvincular, agente desativado pelo responsavel) e quem precisa
/// reagir (roteador, telas do modo crianca) observa [watch].
abstract interface class ILinkStateRepository {
  LinkState get current;

  /// Situacao atual seguida das mudancas.
  Stream<LinkState> watch();

  void update(LinkState state);
}
