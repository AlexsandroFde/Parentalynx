# Relatórios e alertas

Telas: Relatórios (resumo do período, gráficos, aplicativos, categorias, bloqueios), Linha do
tempo do dia, Eventos do aparelho, Histórico de navegação, Central de alertas (lista, detalhe,
não lidos), Preferências de notificação e o pedido de permissão de notificações (mostrado pela
casca do painel). Perfil: responsável.

## Heurísticas consideradas

- **H1 Visibilidade do estado:** toda tela de relatório diz de quando são os dados ("Dados
  recebidos do aparelho há 1 min" ou "Aparelho sem conexão…"); a troca de período mostra
  "Carregando…" e esmaece o relatório anterior; se a troca falha, um aviso diz qual período está
  na tela. Alertas novos têm a etiqueta "Novo"; o pedido de tempo diz se ainda aguarda resposta;
  "marcar todos como lidos" e as preferências só confirmam depois que o servidor aceitou.
- **H2 Mundo real:** "Hoje", "Ontem", "seg 16/11", "1h 20min"; eventos em palavras simples, sem
  código interno nem "versão"; "Conta no limite / Não conta no limite" no lugar de "fora do
  limite"; "Filtro familiar" no lugar de "Filtro DNS familiar".
- **H3 Controle e liberdade:** atalhos de período e "Outras datas"; "Ver todos/Ver menos" nos
  apps; "Voltar para hoje" e calendário na linha do tempo; "Alterar período" em eventos e
  navegação; filtros vazios oferecem a saída ("Ver todos os eventos"); voltar mantém o período.
- **H4 Consistência:** o mesmo cabeçalho (criança, aparelho) e a mesma linha de período em todas
  as telas de relatório; o mesmo número (média por dia) no resumo e no gráfico; um único
  mapeamento de ícone e tom por tipo de alerta, usado pela central, pelas preferências, pela
  prévia do painel e pelo aviso da casca; gráficos só com `AppChartStyle`.
- **H5 Prevenção de erros:** "Marcar todos como lidos" pede confirmação com a consequência (não
  há como voltar a "não lido"); botões ocupados ignoram toque duplo; o interruptor em gravação
  fica travado e diz "Salvando…"; datas escolhidas são corrigidas (sem futuro, até 92 dias).
- **H6 Reconhecimento:** criança e aparelho no topo de cada relatório; período por extenso;
  ícones dos apps; alertas e eventos agrupados por dia; o nome da criança no aviso de pedido.
- **H7 Eficiência:** atalhos de período; "Ver valores" com cada dia levando à sua linha do
  tempo; "Ver eventos" abre os eventos de bloqueio do mesmo período; busca no histórico; do
  alerta direto para responder o pedido, ver o aparelho ou as regras de apps.
- **H8 Minimalismo:** resumo primeiro (`MetricRow`), gráficos só onde a forma importa (dia a dia
  e hora a hora), o resto em listas com o valor exato; endereço completo só no detalhe.
- **H9 Erros:** "Não foi possível carregar o relatório/os alertas/a linha do tempo" + motivo +
  "Tentar de novo"; falha ao atualizar mantém a lista e avisa; preferência recusada diz qual
  foi e que a anterior continua valendo.
- **H10 Ajuda:** botão de ajuda em cada tela (como o tempo é medido, o que conta no limite, o
  que é tentativa bloqueada, o que entra no histórico e quem vê, como os alertas chegam) e o
  motivo antes do pedido de permissão.

## Problemas encontrados e soluções

| # | Tela | Problema | Heurística | Gravidade | Solução | Verificação |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Relatórios | Nada dizia de quando eram os dados: com o aparelho sem sincronizar, o relatório parecia completo. | H1 | Alta | Linha "Dados recebidos do aparelho há 1 min" (ou "Aparelho sem conexão… o uso depois disso aparece quando ele voltar") a partir de `lastSyncAt`/`online`. | `reports_page_test` (texto), `report_texts_test` |
| 2 | Relatórios | Se a troca de período falhava, a tela mostrava o relatório anterior com o novo período selecionado, sem dizer qual estava na tela. | H1, H9 | Alta | Aviso "Não foi possível atualizar o relatório. Mostrando 11/11 a 17/11, o último relatório carregado." + "Tentar de novo"; conteúdo esmaecido; rótulos e atalhos seguem o período dos dados mostrados. | `reports_page_test` (falha ao trocar o período) |
| 3 | Relatórios | Gráficos repetidos ("Evolução do uso" = "Uso por dia"; tentativas por dia em gráfico) e sete cartões iguais. | H8 | Média | Dois gráficos (dia a dia, hora a hora); apps, categorias e bloqueios em listas com barra e valor exato. | `reports_page_test` ("Evolução do uso" ausente), capturas `reports_7_dias*` |
| 4 | Relatórios | Criança e período numa linha cinza pequena; aparelho ausente. | H6 | Média | `AppPageHeader` com criança e aparelho; período por extenso ("11/11 a 17/11 · 7 dias", "Hoje, ter 17/11"). | `reports_page_test` |
| 5 | Relatórios | O atalho "Personalizado" ficava cortado fora da tela (chips em rolagem lateral). | H6, H7 | Média | `AppSegmentedControl` com os quatro atalhos e o botão visível "Outras datas"; com fonte 2× os atalhos viram chips que quebram linha. | `reports_page_test` (fonte 2×) |
| 6 | Relatórios | Cores próprias nos gráficos (uma série abaixo de 3:1), fora da identidade. | H4 | Média | Cores e textos de `AppChartStyle`, legenda em texto para cada série, média como linha tracejada explicada na legenda. | `design_system_test`, capturas claro/escuro |
| 7 | Relatórios | "Fora do limite (exceções)" parecia "passou do limite". | H2 | Média | "Conta no limite / Não conta no limite" e a frase "2h 20min não contaram no limite (apps de exceção ou regras suspensas)". | Captura `reports_7_dias` |
| 8 | Relatórios | Só os 8 apps mais usados, sem como ver o resto. | H3, H7 | Média | "Ver todos / Ver menos" na seção de aplicativos. | Revisão da tela |
| 9 | Relatórios | Nenhuma explicação do que cada número conta. | H10 | Média | Ajuda: como o tempo é medido, o que conta no limite, tentativa bloqueada, quando o dia começa. | Revisão da tela |
| 10 | Relatórios | Tabela de valores sem ligação com o detalhe do dia. | H7 | Baixa | "Ver valores": lista dia a dia ("no limite 2h 10min de 2h 30min · 2 bloqueios") que abre a linha do tempo do dia. | `reports_page_test` |
| 11 | Relatórios | Tentativas bloqueadas sem caminho para os detalhes. | H7 | Baixa | "Ver eventos" abre os eventos já filtrados por Bloqueios, no mesmo período. | `reports_page_test` (tipos e período da consulta) |
| 12 | Relatórios | Carregamento com indicador genérico; erro "Não foi possível carregar" sem o quê. | H1, H9 | Baixa | Esqueleto com a forma do relatório; `ErrorState` "Não foi possível carregar o relatório" + tentar de novo. | `reports_page_test` |
| 13 | Detalhes | Sem aparelho em foco, as telas de detalhe só diziam "Nenhum aparelho vinculado", mesmo carregando ou com falha. | H1, H9 | Baixa | Estados de carregando, falha (tentar de novo) e vazio (vincular aparelho). | `reports_page_test` (sem aparelho) |
| 14 | Linha do tempo | Criança e aparelho ausentes. | H6 | Média | Mesmo cabeçalho dos relatórios. | `report_details_test` |
| 15 | Linha do tempo | Só dia a dia: voltar 10 dias pedia 10 toques. | H7 | Média | Calendário ("Escolher o dia") e "Voltar para hoje" (`DayTimelineDaySelected`, nunca além de hoje). | `report_details_test`, `report_detail_blocs_test` |
| 16 | Linha do tempo | Resumo numa frase; faixa de 24 h sem descrição útil para o leitor de tela. | H8, H1 | Baixa | `MetricRow` (uso, sessões, maior pausa); faixa com rótulo "Primeiro uso às 07:10 e último às 19:50". | `report_details_test` |
| 17 | Linha do tempo | Um cartão por sessão; pausa com ícone de "mais opções". | H8, H2 | Baixa | Blocos de uso em `AppListGroup`, pausa com ícone de pausa e os horários ("Sem uso por 4h 50min, das 07:40 às 12:30"). | `report_details_test`, capturas |
| 18 | Linha do tempo | Dia vazio sem próximo passo; sem puxar para atualizar. | H3, H1 | Baixa | "Ver o dia anterior"; atualizar mantém o dia na tela e avisa a falha. | `report_detail_blocs_test` |
| 19 | Eventos | Tipo desconhecido mostrava o código interno; "Versão 12". | H2 | Média | "Outro registro do aparelho"; "As regras mais recentes passaram a valer." | `report_texts_test` |
| 20 | Eventos | Período e criança não apareciam. | H6 | Média | Cabeçalho + período com "Alterar período". | `report_details_test`, `report_detail_blocs_test` |
| 21 | Eventos | Tom por grupo: todo evento de segurança em vermelho, bloqueio por horário igual a erro. | H4, H2 | Média | Ícone e tom por tipo e motivo: tentativa bloqueada coral, limite ocre, horário e pausa anil (descanso), o que voltou a valer verde. | Capturas `reports_eventos*` |
| 22 | Eventos | Lista sem dias, só tempo relativo. | H6 | Baixa | Grupos "Hoje", "Ontem", "seg 16/11" com o horário. | `report_details_test` |
| 23 | Eventos | Filtro sem resultado sem saída; fim da lista e falha da página seguinte sem aviso claro. | H3, H1 | Baixa | "Ver todos os eventos"; "Isso é tudo do período."; botão ocupado; falha mantém os itens com aviso. | `reports_page_test`, revisão |
| 24 | Navegação | Privacidade numa linha pequena: sem dizer quem vê, por quanto tempo e como apagar. | H10 | Média | Aviso "Só o navegador ParentaLynx" + ajuda (o que entra, a criança sabe, retenção, onde apagar ou exportar). | `report_details_test` |
| 25 | Navegação | Lista longa sem busca. | H7 | Média | Busca por título, site ou endereço, avisando que vale para as páginas já carregadas. | `report_details_test`, `report_detail_blocs_test` |
| 26 | Navegação | Período e criança ausentes. | H6 | Média | Cabeçalho + período com "Alterar período". | `report_details_test` |
| 27 | Navegação | "Filtro DNS familiar" (jargão). | H2 | Baixa | "Filtro familiar". | `report_texts_test` |
| 28 | Navegação | Endereço completo em cada linha (poluição e possível dado sensível). | H8 | Baixa | Site na lista; endereço completo no detalhe, com "Copiar endereço". | Revisão da tela |
| 29 | Alertas | Não lido indicado só por um ponto azul (cor). | H1 | Alta | Etiqueta "Novo" em texto (lida pelo leitor de tela) e título em negrito. | `alerts_center_page_test` |
| 30 | Alertas | "Marcar todos como lidos" irreversível, sem confirmação nem retorno. | H5, H1 | Média | Confirmação com a consequência; aviso só depois do servidor; ação travada durante o envio. | `alerts_center_page_test` |
| 31 | Alertas | Detalhe do pedido de tempo sempre com "Responder pedido", mesmo já respondido. | H1 | Média | "Aguardando a sua resposta" + "Responder pedido", ou "Nenhum pedido de João aguardando" + "Ver pedidos de tempo", pela contagem do aparelho. | `alerts_center_page_test` |
| 32 | Alertas | Tentativa bloqueada em ocre aqui e em coral no painel. | H4 | Média | Um único `AlertVisual` com os tons do Design System, usado pela central, preferências, painel e aviso da casca. | `alerts_center_page_test`, capturas |
| 33 | Alertas | Lista sem dias; aviso de pedido sem nome. | H6 | Baixa | Grupos "Hoje/Ontem"; "João pediu mais tempo de uso". | `alerts_center_page_test` |
| 34 | Alertas | Alertas de apps sem atalho; alerta que não notificou sem caminho para as preferências. | H7, H10 | Baixa | "Ver regras de apps" (foca o aparelho do alerta); aviso com atalho "Preferências". | `alerts_center_page_test` |
| 35 | Alertas | Vazio sem próximo passo; erro genérico. | H3, H9 | Baixa | "Escolher avisos"; "Não foi possível carregar os alertas" + tentar de novo. | `alerts_center_page_test` |
| 36 | Preferências | Doze interruptores numa lista só. | H8, H6 | Média | Grupos por assunto (tempo de uso, aplicativos, aparelho e proteção, conta). | `notification_prefs_page_test` |
| 37 | Preferências | Consequência de desligar não explicada por assunto. | H10, H5 | Média | Rodapé de cada grupo ("Desligado, o pedido de tempo continua esperando…", "Recomendado manter ligados…"). | `notification_prefs_page_test` |
| 38 | Preferências | Gravação só como interruptor desabilitado; recusa sem dizer qual escolha falhou. | H1, H9 | Média | "Salvando…" na linha; "Não foi possível salvar "Novo app instalado". A preferência anterior continua valendo." | `notification_prefs_page_test` |
| 39 | Permissão | Diálogo genérico, três parágrafos, botões fora do Design System. | H8, H4 | Baixa | `showConfirmDialog` com ícone, motivo curto e consequência; "Agora não" / "Ativar". | `guardian_shell_test`, `alerts_center_page_test` |
| 40 | Permissão | Recusa sem dizer o que fazer. | H9 | Baixa | "As notificações continuam desativadas. Ative nas configurações do aparelho." + "Configurações". | Revisão |

Total: 40 problemas — 3 de gravidade alta, 20 média e 17 baixa.

Cada tela principal tem captura nos temas claro e escuro (`reports_7_dias`,
`reports_linha_do_tempo`, `reports_eventos`, `reports_navegacao`, `guardian_alerts`,
`notification_prefs`, com o sufixo `_escuro`), teste com fonte 2× sem exceção e
`expectAccessible` (toque de 48, rótulos e contraste).

## Pendências

- Validar em aparelho real a frase de atualização (`lastSyncAt`) com o aparelho sem conexão por
  horas, e os horários com o celular do responsável em outro fuso (eventos e navegação usam o
  horário deste celular; a linha do tempo, o do aparelho da criança).
- "Marcar como não lido" e busca no servidor não existem na API: a central não oferece desfazer a
  leitura e a busca do histórico vale para as páginas já carregadas (a tela diz isso).
- Os rótulos dentro dos gráficos param de crescer em 1,3× (o lugar dos eixos é fixo); os mesmos
  valores aparecem por inteiro em "Ver valores".
- As capturas do painel (`dashboard_*`) precisam ser regeneradas pela funcionalidade do painel:
  a prévia de alertas usa o `AlertVisual` com os tons novos (tentativa bloqueada em coral, pouco
  tempo em ocre). Essas capturas já divergiam antes desta mudança.
- Pedidos ao Design System: ícone de ligar/desligar o aparelho (hoje usa o do aparelho);
  `AppSwitchRow` com estado ocupado; seleção vazia no `AppSegmentedControl`; e promover os
  padrões repetidos daqui: legenda de gráfico e seção gráfico/valores (`ChartSection`), lista
  paginada agrupada por dia (`PagedListBody`), linha de período (`ReportPeriodRow`) e o rótulo de
  dia ("Hoje", "Ontem", "seg 16/11"), hoje duplicado em relatórios e alertas.
