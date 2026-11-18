/// Perfil com que o app funciona neste aparelho, escolhido na configuracao inicial.
enum UserRole {
  /// Ainda nao escolhido: o app mostra as boas-vindas.
  unset,

  /// Aparelho do responsavel: painel, regras e relatorios.
  guardian,

  /// Aparelho da crianca: agente de controle e tela inicial da crianca.
  child,
}
