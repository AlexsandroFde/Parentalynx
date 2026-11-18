/// Texto da tela de transparencia.
///
/// Espelha a secao 7 de `docs/01-capacidades-android.md`. Se a coleta mudar no agente nativo,
/// este texto precisa mudar junto: e a promessa feita a crianca sobre o que o app ve.
abstract final class TransparencyContent {
  /// O que o responsavel decide.
  static const List<String> controlled = <String>[
    'Quanto tempo o aparelho pode ser usado por dia.',
    'Em quais horários o aparelho pode ser usado.',
    'Quais apps podem ser abertos e quais ficam bloqueados.',
    'Quais sites abrem no Navegador ParentaLynx.',
  ];

  /// O que e registrado e enviado ao responsavel.
  static const List<String> collected = <String>[
    'A lista de apps instalados neste aparelho.',
    'Quanto tempo cada app foi usado e em quais horários.',
    'Quando você tenta abrir um app bloqueado.',
    'Quando o aparelho é bloqueado e quando é liberado.',
    'Se uma permissão do controle foi desligada, se o relógio foi mudado e quando o aparelho '
        'foi reiniciado.',
    'O nível da bateria.',
    'Os sites abertos dentro do Navegador ParentaLynx: o endereço e o título da página.',
  ];

  /// O que o app nao registra e nao consegue acessar.
  static const List<String> neverCollected = <String>[
    'Suas mensagens e conversas.',
    'O que você digita e as suas senhas.',
    'O que aparece na tela. Ele não tira foto nem grava a tela.',
    'Suas fotos, vídeos e arquivos.',
    'O microfone e a câmera.',
    'Onde você está.',
    'Seus contatos e suas ligações.',
    'Os sites que você abre em outros navegadores ou em outros apps.',
  ];

  static const String alwaysVisible =
      'O ParentaLynx nunca fica escondido. O ícone continua na lista de apps, uma notificação '
      'mostra que o controle está ativo e você pode abrir esta página sempre que quiser.';

  static const String emergency =
      'Ligações de emergência nunca são bloqueadas, mesmo quando o tempo acaba.';
}
