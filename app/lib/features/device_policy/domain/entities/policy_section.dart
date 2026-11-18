import 'policy.dart';

/// Uma secao editavel da politica (limite diario, horarios, apps, web, protecao...).
///
/// Estrategia usada pelo salvamento por secao: cada funcionalidade de regras define a sua
/// secao (como ler e como gravar no documento), e o caso de uso `SavePolicySection` cuida da
/// versao, do conflito e da confirmacao da mesma forma para todas.
///
/// O valor da secao precisa ter igualdade por valor, para que se possa saber se ela mudou no
/// servidor durante a edicao.
abstract interface class PolicySection<T> {
  /// Le a secao do documento.
  T read(Policy policy);

  /// Devolve o documento com a secao trocada.
  Policy write(Policy policy, T value);
}
