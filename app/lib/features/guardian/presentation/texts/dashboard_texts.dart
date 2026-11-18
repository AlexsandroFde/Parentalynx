/// Textos do painel derivados do estado do aparelho. Funcoes puras.
library;

/// Traduz um problema de aplicacao das regras (`enforcement.issues` do protocolo) em um aviso
/// compreensivel para o responsavel.
({String title, String message}) describeIssue(String issue) {
  return switch (issue) {
    'accessibility_disabled' => (
      title: 'Serviço de acessibilidade desativado',
      message:
          'O bloqueio de apps pode não funcionar. Reative o serviço do ParentaLynx nas '
          'configurações de acessibilidade do aparelho da criança.',
    ),
    'usage_access_missing' => (
      title: 'Acesso ao uso revogado',
      message:
          'A contagem de tempo ficou menos precisa ou indisponível. Reative o "Acesso ao '
          'uso" no aparelho da criança.',
    ),
    'overlay_missing' => (
      title: 'Sobreposição não concedida',
      message: 'A tela de bloqueio pode não aparecer se a acessibilidade for desativada.',
    ),
    'notifications_disabled' => (
      title: 'Notificações desligadas no aparelho',
      message: 'A criança não recebe os avisos de tempo acabando.',
    ),
    'battery_optimized' => (
      title: 'Economia de bateria ativa para o app',
      message:
          'O sistema pode encerrar o controle com a tela apagada. Libere o ParentaLynx da '
          'otimização de bateria no aparelho da criança.',
    ),
    'suspend_failed' => (
      title: 'Falha ao suspender apps',
      message: 'O sistema recusou suspender algum app. O bloqueio usa a interceptação.',
    ),
    'policy_invalid' => (
      title: 'Regras não aplicadas',
      message: 'O aparelho não conseguiu aplicar a versão atual das regras.',
    ),
    'clock_untrusted' => (
      title: 'Relógio do aparelho não confirmado',
      message: 'O aparelho está sem a hora do servidor. O dia da cota pode estar impreciso.',
    ),
    _ => (title: 'Problema na proteção', message: 'O aparelho informou o problema "$issue".'),
  };
}
