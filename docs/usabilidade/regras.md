# Regras

Telas: visão geral das regras ("Regras de João"), estrutura comum dos editores (inclui conflito de
versão e aparelho em foco), limite diário, pedidos de tempo, horários permitidos, períodos de
bloqueio, aplicativos (lista e folha do app), exceções e funções essenciais, navegação na internet
e proteção. Perfil: responsável.

## Heurísticas consideradas

- **H1 Visibilidade do estado:** todo editor mostra, logo abaixo do título, se a versão atual já
  vale no aparelho (`PolicySyncStatusView`), "Enviando as alterações" durante o envio e, depois de
  salvar, "Aguardando o aparelho confirmar" até o aparelho confirmar — mesmo antes de a lista de
  aparelhos ser atualizada (`effectivePolicySync`). A barra fixa só aparece com alterações e diz o
  que acontece ao salvar; regras desligadas aparecem com o ícone neutro na visão geral.
- **H2 Linguagem do mundo real:** sem nomes de pacote na lista de apps, "Navegador ParentaLynx" em
  vez de "navegador gerenciado", opções explicadas em frases ("Tudo, menos o que você bloquear").
- **H3 Controle e liberdade:** descartar, sair com "Salvar e sair / Descartar / Continuar
  editando", refazer as alterações recusadas por um conflito, "Desfazer" ao tirar uma exceção, ao
  remover um site e ao voltar para o mesmo tempo todos os dias.
- **H4 Consistência:** os sete editores usam a mesma estrutura (cabeçalho, estado, seções,
  `StickyActionBar`, avisos de falha e conflito), as mesmas folhas (`showAppSheet`) e as mesmas
  confirmações (`showConfirmDialog`).
- **H5 Prevenção de erros:** horário sobreposto ou fora de ordem é recusado com explicação (regra
  no domínio), período pontual que já terminou é recusado, cópia de horários pede confirmação com
  a consequência, bloqueio em massa pede confirmação destrutiva, "Escolher apps" fica bloqueado com
  alterações pendentes, botão de salvar ocupado e controles parados durante o envio.
- **H6 Reconhecimento:** "JOÃO · MOTO G54" no topo de cada editor, resumo da semana do limite,
  horários de cada dia visíveis de uma vez, contagens nos filtros de apps.
- **H7 Eficiência:** atalhos de limite (1h, 2h, 2h 30min, 3h), modelos de período (Hora de dormir,
  Escola), atalhos de dias, cópia de horários para seg a sex / sáb e dom / todos, atalhos de limite
  por app, busca e filtros com contagem, "Aplicar a todos" (operação já existente no BLoC).
- **H8 Estética e minimalismo:** um painel por lista (`AppListGroup`) em vez de um cartão com
  borda por item, divulgação progressiva (apps novos, itens essenciais e travas em folhas), cor só
  com significado (ícone do app sem cores aleatórias).
- **H9 Erros:** falha ao salvar diz o que houve, que nada foi enviado, que as regras anteriores
  continuam valendo e que as alterações continuam na tela, com "Tentar de novo"; conflito explicado
  em palavras simples com caminho de recuperação.
- **H10 Ajuda:** botão "?" em cada editor e na aba, com perguntas e respostas curtas (o que conta no
  limite, exceções, funções essenciais, níveis de proteção, filtro familiar, fuso dos horários).

## Problemas encontrados e soluções

| # | Tela | Problema | Heurística | Gravidade | Solução | Verificação |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Editores e visão geral | Logo depois de salvar, a regra aparecia como "aplicada" até a lista de aparelhos ser atualizada. | H1 | Alta | `effectivePolicySync` considera a versão que a tela conhece: fica "Aguardando o aparelho confirmar" até a confirmação. | `screen_time_pages_test` (salvar fica pendente), `rules_overview_page_test` (versão não confirmada) |
| 2 | Editores | Falha ao salvar só aparecia em um aviso passageiro, sem dizer o que continua valendo. | H9 | Alta | Aviso fixo no topo (o que houve, nada foi enviado, regras anteriores valendo, alterações mantidas) + "Tentar de novo" na barra fixa. | `screen_time_pages_test` (falha ao salvar) |
| 3 | Editores | Conflito de versão descartava as alterações e pedia para refazê-las de memória. | H3, H6, H9 | Alta | Aviso no topo explica o conflito; as alterações recusadas ficam guardadas e "Refazer minhas alterações" as aplica sobre a versão nova. | `screen_time_pages_test` (conflito) |
| 4 | Editores (aparelho em foco) | Enquanto a lista de aparelhos carregava, a tela dizia "Nenhum aparelho vinculado". | H1 | Alta | O portão trata carregando, erro (tentar de novo) e vazio (com "Vincular aparelho"). | `rules_overview_page_test` (editor sem aparelho) |
| 5 | Proteção | No modo padrão as travas do sistema apareciam ligadas (desabilitadas), sem efeito real. | H1 | Alta | Sem dispositivo gerenciado as chaves não aparecem; explicação e folha "Ver o que as travas fazem". | `blocking_pages_test` (modo comum) |
| 6 | Editores | Nenhum editor dizia de qual criança e aparelho eram as regras. | H6 | Média | Cabeçalho com "JOÃO · MOTO G54", título e o que a regra faz. | `screen_time_pages_test` |
| 7 | Editores | Barra "Alterações não salvas" sem consequência e sem estado de envio. | H1, H5 | Média | `StickyActionBar` com a consequência, "Salvando" ocupado, descartar desabilitado e controles parados durante o envio. | `screen_time_pages_test` |
| 8 | Editores | Sem ajuda contextual para limite, exceções, proteção e filtros. | H10 | Média | `HelpButton` com tópicos em todos os editores e na aba. | Capturas |
| 9 | Visão geral | Um cartão com borda por grupo, sem agrupamento. | H8 | Média | Grupos por assunto em `AppListGroup` ("Tempo e horários", "Uso dos aplicativos", "Internet e segurança"). | `rules_visao_geral_*` |
| 10 | Limite diário | Sem atalhos para limites comuns. | H7 | Média | `AppChoiceChips` com 1h, 2h, 2h 30min e 3h; valor exato no seletor. | `screen_time_pages_test` (atalho) |
| 11 | Limite diário | Voltar ao mesmo tempo todos os dias apagava os valores de cada dia sem aviso. | H3, H5 | Média | Aviso "Agora vale 2h 30min todos os dias" com "Desfazer" (restaura cada dia). | Revisão de código (sem teste automatizado) |
| 12 | Horários permitidos | Janelas sobrepostas eram aceitas. | H5 | Média | `validateNewDayWindow` no domínio, conferida na folha e no BLoC, com a explicação do conflito. | `schedules_domain_test`, `schedule_pages_test` |
| 13 | Horários permitidos | "Copiar para todos os dias" trocava a semana inteira sem confirmação. | H3, H5 | Média | Confirmação com a consequência e alvos seg a sex / sáb e dom / todos (evento `AllowedHoursDayCopied`). | `schedule_pages_test` (copiar) |
| 14 | Horários permitidos | Sete cartões com chips; a semana não era legível de uma vez. | H6, H8 | Média | Uma lista com os horários de cada dia; folha do dia para liberar, remover e copiar. | `rules_horarios_*` |
| 15 | Períodos de bloqueio | Período pontual que já terminou era aceito. | H5 | Média | `BlockPeriodDraft.problemAt(agora)`. | `schedules_domain_test` |
| 16 | Aplicativos | Nome do pacote em todas as linhas. | H2 | Média | Só o nome do app na lista; o identificador fica na folha do app. | `app_management_pages_test` |
| 17 | Aplicativos | Apps novos aguardando decisão não tinham destaque. | H1 | Média | Aviso com a contagem e "Ver apps novos". | `app_management_pages_test` |
| 18 | Aplicativos | Etiqueta de estado cortava com fonte grande. | Acessibilidade | Média | Com fonte grande a etiqueta vai para baixo do nome. | Teste de fonte 2× |
| 19 | Exceções | Tirar uma exceção não podia ser desfeito. | H3 | Média | Aviso com "Desfazer". | `app_management_pages_test` |
| 20 | Exceções | "Escolher apps" com alterações pendentes abria outro editor da mesma seção e uma das telas perderia o trabalho. | H5 | Média | Bloqueado com a explicação "Salve ou descarte as alterações...". | `app_management_pages_test` |
| 21 | Navegação | Sem explicação do filtro familiar e das categorias. | H10 | Média | Tópicos de ajuda e textos de apoio. | Capturas |
| 22 | Pedidos de tempo | Falha ao aprovar ou negar mostrava só o motivo técnico. | H9 | Média | "Não foi possível responder o pedido." + motivo. | Revisão de código |
| 23 | Editores | Carregamento em tela branca com indicador. | H1, H8 | Baixa | Cabeçalho já visível + esqueletos; erro com o assunto e "Tentar de novo". | Revisão |
| 24 | Editores | Diálogo de saída com botões do Material e sem consequência. | H3, H4 | Baixa | Diálogo composto com o Design System, com a consequência. | Revisão |
| 25 | Editores | Confirmação de envio genérica. | H1 | Baixa | "Alterações salvas. O aparelho de João aplica em instantes." (variante sem conexão). | `screen_time_pages_test` |
| 26 | Visão geral | Regra desligada igual a uma ligada. | H1, H6 | Baixa | Ícone neutro + resumo ("Desligado"). | `rules_overview_page_test` |
| 27 | Visão geral | "Navegador gerenciado" e "(1)" no resumo. | H2 | Baixa | "Navegador ParentaLynx desligado", "Só 1 site autorizado". | `blocking_texts_test` |
| 28 | Limite diário | Valores por dia sem resumo. | H6 | Baixa | Rodapé "Seg a sex: 2h 30min · sáb e dom: 4h". | `screen_time_texts_test` |
| 29 | Limite diário | Avisos desabilitados sem explicação; aviso maior que o limite do dia. | H5, H9 | Baixa | Texto "Você escolheu 4 avisos, o máximo" e aviso quando um aviso é maior que o tempo de algum dia. | Revisão |
| 30 | Limite diário | "Todos os dias às 00:00 · Alterar" pouco claro. | H2 | Baixa | Linha "Horário de reinício" com o valor e a explicação no rodapé. | Captura |
| 31 | Horários permitidos | Dias bloqueados só com uma etiqueta vermelha. | H1 | Baixa | Aviso nomeando os dias e ícone de atenção na linha do dia. | `schedule_pages_test` |
| 32 | Períodos de bloqueio | Modelos só com a lista vazia. | H7 | Baixa | Modelos e atalhos de dias também na folha de novo período. | `rules_periodos_folha` |
| 33 | Períodos de bloqueio | Chave em cada linha com semântica ambígua; nome sem marca de obrigatório. | H4, H5 | Baixa | "Período ativo" na folha, etiquetas "Desativado"/"Encerrado", campo obrigatório marcado. | `schedule_pages_test` |
| 34 | Períodos de bloqueio | Exclusão sem dizer quando vale. | H3 | Baixa | Confirmação destrutiva com a consequência. | Revisão |
| 35 | Aplicativos | Filtros sem contagem; busca vazia sem saída. | H6, H3 | Baixa | Contagem em cada filtro e "Limpar filtros" no vazio. | `app_management_pages_test` |
| 36 | Aplicativos | Cartão por app e ícones com cores aleatórias. | H8 | Baixa | Lista agrupada construída sob demanda e inicial no tom da marca. | `rules_aplicativos_*` |
| 37 | Folha do app | "Aplicar" sugeria que já valia no aparelho; limite só pelo seletor. | H1, H7 | Baixa | "Concluir" + "A mudança vai para o aparelho quando você salvar"; atalhos de limite. | `app_management_pages_test` |
| 38 | Aplicativos | Padrão para apps novos em botões sem explicação. | H2, H10 | Baixa | Linha com o estado atual e folha com as duas opções explicadas. | Captura |
| 39 | Exceções | Itens essenciais com nomes de pacote em lista expansível. | H2, H8 | Baixa | Linha que abre uma folha só com os nomes. | `app_management_pages_test` |
| 40 | Navegação | Chaves desabilitadas sem dizer por quê. | H1 | Baixa | Rodapé "O histórico e a busca segura dependem do navegador ParentaLynx". | Revisão |
| 41 | Navegação | "Lista de bloqueio / Só autorizados" sem explicação. | H2 | Baixa | Opções com frases ("Tudo, menos o que você bloquear"). | `blocking_pages_test` |
| 42 | Navegação | Remover site sem desfazer; chips pequenos. | H3 | Baixa | Linhas com botão de remover (48dp) e "Desfazer". | `blocking_pages_test` |
| 43 | Proteção | Garantias do modo sem hierarquia. | H2 | Baixa | Etiqueta do nível + itens com ícone de garantido/atenção; ajuda dos níveis. | Captura |
| 44 | Pedidos de tempo | Confirmação não dizia que vale só hoje nem quando chega ao aparelho. | H1 | Baixa | "45min a mais para João hoje. O aparelho recebe em instantes."; negar diz quem é avisado e que o limite não muda. | `screen_time_pages_test`, `time_requests_bloc_test` |
| 45 | Pedidos de tempo | Só valores fixos ao aprovar. | H7 | Baixa | "Outro tempo" com o seletor (até 12h). | Revisão |
| 46 | Pedidos de tempo | "Negado" com a cor de erro. | H4 | Baixa | Tom neutro (é uma decisão, não um erro). | `pedidos_de_tempo_*` |
| 47 | Pedidos de tempo | Horários relativos usavam o relógio do sistema, não o do app. | H1 | Baixa | `Clock` do app em "há 5 min". | Capturas estáveis |

Total: 5 de gravidade alta, 17 média e 25 baixa.

Cada tela principal tem captura clara e escura, teste com fonte 2× (sem exceções nem estouro) e
`expectAccessible` (área de toque de 48, rótulos e contraste): visão geral, limite diário, pedidos
de tempo, horários permitidos (e folha do dia), períodos de bloqueio (e folha de novo período),
aplicativos (e folha do app), exceções, navegação e proteção.

## Pendências

- Conferir em aparelho real a leitura do TalkBack nas linhas agrupadas e nas folhas, e os seletores
  de data e hora do Material com fonte 2×.
- O desfazer do "mesmo tempo todos os dias" (item 11) não tem teste automatizado.
- O rodapé da visão geral mostra o fuso no formato técnico (America/Fortaleza) entre parênteses.
- Pedidos ao Design System: componente de chips de seleção múltipla (hoje `FilterChip` direto nos
  avisos e nos dias), lista agrupada construída sob demanda para listas longas (hoje
  `_GroupedRow` em `apps_rules_page.dart`), variante de botão terciário destrutivo (diálogo de
  saída), `AppListRow` que move o complemento para baixo com fonte grande, e revisar o contraste
  de textos longos em `AppBanner` de tom informativo (a regra de contraste do Flutter falhou em um
  texto longo; a tela de proteção passou a usar um painel neutro).
