import '../../../../shared/design_system/design_system.dart';

/// Ajuda dos relatorios: o que cada numero conta.
const List<HelpTopic> reportsHelpTopics = <HelpTopic>[
  HelpTopic(
    title: 'Como o tempo de uso é medido?',
    body:
        'O aparelho da criança registra quanto tempo cada app fica aberto na tela, pela '
        'permissão de acesso ao uso do Android. Os dados chegam aqui quando o aparelho se '
        'conecta ao servidor; a data de envio aparece abaixo do período.',
  ),
  HelpTopic(
    title: 'O que conta no limite?',
    body:
        'O tempo nos apps que contam para o limite diário. Apps de exceção (sempre liberados) '
        'e o tempo com as regras suspensas entram no total, mas não no limite.',
  ),
  HelpTopic(
    title: 'O que é uma tentativa bloqueada?',
    body:
        'Cada vez que a criança tentou abrir um app bloqueado ou fora do horário permitido, o '
        'aparelho mostrou a tela de bloqueio e registrou a tentativa.',
  ),
  HelpTopic(
    title: 'Quando o dia começa?',
    body:
        'Os dias seguem o fuso e o horário de reinício do limite do aparelho da criança, não o '
        'deste celular.',
  ),
];

/// Ajuda da linha do tempo de um dia.
const List<HelpTopic> timelineHelpTopics = <HelpTopic>[
  HelpTopic(
    title: 'O que é uma sessão?',
    body: 'O tempo em que um app ficou aberto na tela, do momento em que abriu até sair dele.',
  ),
  HelpTopic(
    title: 'O que são as pausas?',
    body: 'Intervalos de pelo menos 15 minutos sem nenhum app em uso.',
  ),
  HelpTopic(title: 'Que horário aparece?', body: 'O horário do aparelho da criança, no fuso dele.'),
];

/// Ajuda dos eventos do aparelho.
const List<HelpTopic> eventsHelpTopics = <HelpTopic>[
  HelpTopic(
    title: 'De onde vêm os eventos?',
    body:
        'O aparelho da criança registra bloqueios, limites, pedidos de tempo e mudanças de '
        'permissão ou de proteção, e envia ao servidor quando está conectado.',
  ),
  HelpTopic(
    title: 'Quando dar atenção?',
    body:
        'Eventos de segurança (relógio alterado, senha errada no aparelho, permissão '
        'desativada, desvinculação) podem indicar uma tentativa de contornar as regras. '
        'Confira o aparelho e as permissões.',
  ),
];

/// Ajuda do historico de navegacao: o que entra e quem ve (privacidade).
const List<HelpTopic> browsingHelpTopics = <HelpTopic>[
  HelpTopic(
    title: 'O que entra no histórico?',
    body:
        'Só as páginas abertas ou bloqueadas no navegador ParentaLynx do aparelho da criança. '
        'Outros navegadores e apps não são registrados.',
  ),
  HelpTopic(
    title: 'A criança sabe?',
    body:
        'Sim. O navegador mostra para a criança que o responsável vê o histórico. O registro '
        'pode ser desligado em Regras, Navegação na internet.',
  ),
  HelpTopic(
    title: 'Por quanto tempo fica guardado?',
    body:
        'Pelo prazo de retenção definido em Mais, Privacidade. O histórico de um aparelho pode '
        'ser exportado ou apagado em Mais, Aparelhos vinculados.',
  ),
];
