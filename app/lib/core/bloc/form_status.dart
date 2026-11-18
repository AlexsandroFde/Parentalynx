/// Andamento de um formulario (entrar, criar conta, informar codigo).
///
/// Um unico valor em vez de varios booleanos (`busy`, `done`), para que o estado nunca
/// fique em uma combinacao impossivel.
enum FormStatus {
  /// A pessoa esta preenchendo. Erros de validacao, quando houver, ficam no estado.
  editing,

  /// Enviando. Os campos e o botao ficam desabilitados.
  submitting,

  /// Aceito. A tela segue para o proximo passo.
  succeeded;

  bool get isSubmitting => this == FormStatus.submitting;
}
