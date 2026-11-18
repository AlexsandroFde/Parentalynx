/// Estado de um app como o responsavel deve enxerga-lo.
enum EffectiveAppState {
  allowed('Permitido'),
  blocked('Bloqueado'),
  exception('Exceção'),

  /// Sem regra, com "bloquear apps novos" ligado: bloqueado ate o responsavel decidir.
  pendingApproval('Aguardando aprovação'),

  /// Funcao essencial do sistema: nunca e bloqueada e nao pode ser configurada.
  essential('Essencial');

  const EffectiveAppState(this.label);

  final String label;

  /// Verdadeiro quando o app nao pode ser aberto.
  bool get isBlocked {
    return this == EffectiveAppState.blocked || this == EffectiveAppState.pendingApproval;
  }
}
