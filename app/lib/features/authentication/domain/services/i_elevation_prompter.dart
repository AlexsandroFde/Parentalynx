/// Pede ao responsavel a confirmacao da senha administrativa e eleva a sessao.
///
/// E uma porta do dominio: o caso de uso `RunElevated` sabe *quando* pedir; a implementacao
/// (um dialogo, na camada de apresentacao) sabe *como*.
abstract interface class IElevationPrompter {
  /// Devolve verdadeiro quando a senha foi aceita e a sessao ficou elevada. Falso quando a
  /// pessoa desistiu.
  Future<bool> requestElevation();
}
