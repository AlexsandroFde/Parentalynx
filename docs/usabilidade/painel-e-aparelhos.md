# Painel, aparelhos e vinculação

Telas: casca do painel (navegação, selo de alertas, aviso de alerta em tempo real, pedido de
permissão de notificações), Início (com aparelho, bloqueado, sem aparelho, carregando, erro),
lista de aparelhos, detalhe do aparelho, código de acesso offline, troca de nome, vinculação
(gerar código, pedido, aprovação, sucesso). Perfil: responsável.

## Heurísticas consideradas

- **H1 Visibilidade do estado.** O Início mostra de quem é o aparelho, a conexão ("Online",
  "Visto por último há 5 min"), a bateria e, com o `PolicySyncStatusView`, se as regras atuais
  já valem no aparelho. Depois de um comando (tempo extra, pausa, suspensão) o estado vira
  "Aguardando o aparelho confirmar" até o aparelho confirmar a versão nova; a pausa ainda não
  confirmada aparece como "Pausa aguardando o aparelho". O bloqueio diz a regra que bloqueou e
  quando libera. O botão tocado mostra o andamento; a confirmação só aparece depois da resposta
  do servidor e diz se o aparelho está sem conexão. Na vinculação, o passo atual aparece no
  cabeçalho e na lista de passos, a validade do código aparece em contagem e em horário, e o
  código vencido é explicado.
- **H2 Mundo real.** "Tempo de hoje", "restam hoje", "Uso total", "Pausado por você",
  "Visto por último"; nenhum código interno (os problemas do aparelho viram frases com o efeito
  e o que fazer).
- **H3 Controle e liberdade.** Pausa e suspensão podem ser encerradas no aviso e no botão;
  todas as confirmações têm "Cancelar"; "Aparelho não encontrado" e "Vínculo revogado" levam a
  uma saída (lista de aparelhos, vincular de novo).
- **H4 Consistência.** Mesmos componentes do Design System em todas as telas; a prévia de
  alertas usa o ícone e o tom da central de alertas; o estado de conexão vem de uma única
  função para painel, lista e detalhe; restrições combinadas usam o tom de descanso, e o
  vermelho fica para erro e ações destrutivas.
- **H5 Prevenção de erros.** Pausar e suspender passam por uma confirmação com o prazo e o
  horário em que tudo volta; suspender exige escolher uma regra; aprovar o vínculo exige marcar
  que o número de confirmação é o mesmo nos dois aparelhos; ações destrutivas mostram a
  consequência na própria linha e no diálogo (reversível ou permanente); botões ficam fora de
  alcance enquanto um comando roda; tempo extra some quando não há limite e avisa que não
  libera fora do horário permitido.
- **H6 Reconhecimento.** Criança e aparelho no topo de toda tela; seletor de aparelho com o
  modelo quando dois nomes se repetem; resumo do pedido (aparelho e número) dentro da aprovação.
- **H7 Eficiência.** Valores prontos de tempo extra, "Outro valor", atalhos para ajustar o
  limite, ver pedidos de tempo, relatórios, detalhes do aparelho e definir as regras logo depois
  de vincular; puxar para atualizar recarrega também os comandos em vigor.
- **H8 Minimalismo.** O Início deixou de ser uma pilha de cartões iguais: cabeçalho de estado,
  avisos só quando há algo a resolver, um número em destaque, ações, duas listas agrupadas e a
  proteção resumida em duas linhas (detalhes no aparelho).
- **H9 Erros.** Falhas dizem a operação ("O tempo extra não foi enviado.", "O código não foi
  cancelado e continua valendo.") seguida do motivo e, nos comandos do painel, "Tentar de novo".
  Permissões desativadas dizem o efeito e como reativar no aparelho da criança.
- **H10 Ajuda.** `HelpButton` no Início (como o tempo é contado, quando uma mudança vale,
  pausar x suspender, aparelho que não sincroniza), na vinculação (como funciona, por que
  conferir o número, código vencido, o que acontece depois) e no aparelho (nível de proteção,
  reativar permissões, código offline, desvincular x apagar). Sem aparelho, o Início explica o
  caminho em passos.

## Problemas encontrados e soluções

| # | Tela | Problema | Heurística | Gravidade | Solução | Verificação |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Início | Depois de um comando o cabeçalho continuava "Regras aplicadas no aparelho", sem esperar a confirmação do aparelho. | H1 | Alta | O estado de sincronização conta a versão devolvida pelo comando (`policySync`); `PolicySyncStatusView` no cabeçalho. | `dashboard_page_test` "tempo extra envia, confirma e fica aguardando o aparelho"; `guardian_dashboard_bloc_test` (pausa) |
| 2 | Início | Mensagens "enviada" davam o comando como feito e não diziam quando o aparelho está sem conexão. | H1 | Média | "Pausa salva. O aparelho de João recebe em instantes." ou "...está sem conexão e recebe quando voltar." | `guardian_dashboard_bloc_test` |
| 3 | Início | Pausar mandava direto de uma lista simples; suspender não dizia quando as regras voltam. | H5, H6 | Média | Folhas de confirmação com o prazo ("Volta ao normal às 16:00", "As regras voltam a valer às ...") e botão que nomeia a ação. | "pausar pede confirmacao com o prazo e so envia depois" |
| 4 | Início | Suspender sem regra marcada só desabilitava o botão, sem explicar. | H5, H9 | Baixa | Mensagem "Escolha pelo menos uma regra para suspender." | "suspender exige escolher pelo menos uma regra" |
| 5 | Início | Nenhum andamento nos botões; dois comandos podiam correr juntos. | H1, H5 | Média | `lastCommand`/`runningCommand`: o botão tocado mostra o andamento e os outros esperam. | `guardian_dashboard_bloc_test` (estados com o comando) |
| 6 | Início | Falha de comando mostrava só o motivo da rede, sem a operação e sem repetir. | H9 | Média | "O tempo extra não foi enviado. <motivo>" com "Tentar de novo" (pausa e suspensão voltam à confirmação). | "falha no comando diz o que nao foi feito e oferece tentar de novo" |
| 7 | Início | Limite atingido em vermelho (anel e aviso), como erro. | H4, H8 | Média | Tom de descanso, a regra que bloqueou e "Libera amanhã às 00:00". Vermelho só para proteção desativada. | "bloqueio mostra a regra que bloqueou e quando libera"; `dashboard_bloqueado*.png` |
| 8 | Início | Pausa encerrada aqui, mas o aparelho ainda bloqueado, sem explicação. | H1 | Média | Aviso "Retomada aguardando o aparelho". | Revisão do código (estado raro de reproduzir no teste) |
| 9 | Início | Pilha de cartões com borda; nível de proteção listado por inteiro no painel. | H8 | Média | Hierarquia por seções; proteção em duas linhas que levam ao detalhe do aparelho. | `dashboard_liberado*.png` |
| 10 | Início | Um aviso amarelo por problema de proteção, sem caminho para resolver. | H8, H9 | Média | Um aviso (com o efeito e o que fazer, ou o resumo de vários) e "Ver o aparelho". | "protecao degradada aparece como aviso com o que fazer" |
| 11 | Início | Ícones e tons dos alertas diferentes da central de alertas. | H4 | Baixa | Prévia usa `AlertVisual` da central; "Novo" nos não lidos. | `dashboard_liberado*.png` |
| 12 | Início | Tempo extra oferecido sem limite diário (sem efeito) e sem avisar que não libera fora do horário. | H5 | Média | Esconde sem limite ("Definir limite"); nota fora do horário permitido. | Revisão do código e capturas |
| 13 | Início | "Total no aparelho" x "Usado" sem explicação. | H2, H10 | Baixa | "Uso total" e a pergunta "Como o tempo é contado?" na ajuda. | `dashboard_liberado.png` |
| 14 | Início | Sem ajuda contextual. | H10 | Média | `HelpButton` com quatro perguntas. | Capturas (botão na barra) |
| 15 | Início | "Ver pedidos" de tempo levava para a central, não para os pedidos. | H7 | Baixa | Vai direto para os pedidos de tempo. | "pedido de tempo pendente leva aos pedidos" |
| 16 | Início | Sem aparelho: estado vazio sem explicar o processo; pedido de vínculo de outro aparelho invisível com um aparelho já ativo. | H10, H1 | Média | Lista "Como funciona" em passos, ação principal; aviso de pedido de vínculo no painel. | `dashboard_sem_aparelho*.png` |
| 17 | Início | Carregamento em tela branca com indicador. | H1 | Baixa | Esqueleto com a forma do painel; listas carregam e falham cada uma no seu lugar, com "Tentar de novo". | Revisão do código |
| 18 | Início, Regras, Relatórios | Seletor de aparelho rolava de lado (opções escondidas) e nomes repetidos ficavam ambíguos. | H6 | Baixa | `AppChoiceChips` em quebra de linha e modelo junto ao nome repetido. | Revisão do código |
| 19 | Início | Puxar para atualizar não recarregava os comandos em vigor. | H1 | Baixa | A atualização recarrega também a política. | `guardian_dashboard_bloc_test` (atualizar) |
| 20 | Início | Com fonte 2×, o número no anel encolhia. | Acessibilidade | Média | A frase "Restam 1h 20min de 2h 30min hoje." aparece abaixo do anel. | "funciona com a fonte no maior tamanho" |
| 21 | Casca | Pedido de notificações na primeira abertura, antes de existir aparelho. | H10, H8 | Média | O pedido espera o primeiro aparelho ativo, quando os avisos passam a fazer sentido. | "sem aparelho vinculado espera o primeiro aparelho para pedir as notificacoes" |
| 22 | Casca | Aviso de alerta sumia em 5 s mesmo com leitor de tela. | Acessibilidade, H3 | Média | Com leitor de tela o aviso fica até ser dispensado. | Revisão do código (pendente em aparelho) |
| 23 | Casca | Ícones da navegação fora do Design System; aviso sem o ícone do tipo de alerta; contagem no singular errada. | H4, H2 | Baixa | `AppIcons`, ícone do tipo de alerta, "1 não lido"/"3 não lidos". | `guardian_shell_alerta*.png`; testes da casca |
| 24 | Vinculação | Aprovar só pedia o nome; o número de confirmação podia ser ignorado. | H5 | Alta | A aprovação mostra o aparelho e o número de novo e exige marcar "O mesmo número aparece no aparelho da criança". | "vinculacao: gera o codigo e mostra o pedido com a confirmacao"; "aprovar mostra o sucesso..." |
| 25 | Vinculação | Código vencido sumia da tela sem explicação. | H1, H9 | Média | Aviso "O código venceu" e "Gerar código". | "codigo vencido explica o que houve e oferece gerar outro"; `device_linking_bloc_test` |
| 26 | Vinculação | Não dava para saber em que passo se estava. | H1, H6 | Média | Cabeçalho "Passo N de 4" com a instrução do passo; lista de passos com o atual. | Capturas `guardian_pairing_*` |
| 27 | Vinculação | Validade só em contagem regressiva. | H6 | Baixa | "Vale até as 15:44, uma única vez." | Teste da vinculação |
| 28 | Vinculação | Falhas sem dizer a operação nem o que continua valendo. | H9 | Média | "O código não foi gerado.", "O código não foi cancelado e continua valendo." etc. | Revisão do código |
| 29 | Vinculação | Antes da primeira consulta oferecia gerar código mesmo com pedido esperando. | H1, H5 | Baixa | Esqueleto até a primeira resposta. | Revisão do código |
| 30 | Vinculação | Ajuda limitada aos passos. | H10 | Média | `HelpButton` (segurança do número, código vencido, depois de aprovar). | Capturas |
| 31 | Vinculação | Sucesso com avisos soltos e sem atalho para as regras; aprovar e rejeitar com o mesmo indicador. | H7, H1 | Baixa | "Falta pouco" em passos, "Definir as regras agora"; andamento separado em cada botão. | Revisão do código |
| 32 | Aparelho | Permissões como "Acessibilidade: desativada" sem dizer como resolver. | H9 | Média | Aviso com efeito e o que fazer; permissões separadas em essenciais e reforço, com etiqueta "Ativa"/"Desativada". | "detalhe do aparelho mostra o nivel de protecao e as permissoes com o que fazer" |
| 33 | Aparelho | Ações destrutivas como botões vermelhos empilhados, sem a consequência antes do toque; confirmação sem destacar o que não volta. | H5, H3 | Média | Linhas com a consequência; `showConfirmDialog(destructive:, consequence:)` distinguindo desvincular (reversível) de apagar (permanente). | "desvincular pede confirmacao..."; "apagar o aparelho pede confirmacao..." |
| 34 | Aparelho | Qualquer ação desabilitava tudo sem mostrar qual estava rodando. | H1 | Baixa | `ChildDeviceTask`: o controle tocado mostra o andamento. | `child_device_bloc_test` |
| 35 | Aparelho | "Aparelho não encontrado" e "Vínculo revogado" sem saída. | H3 | Baixa | "Ver aparelhos" e "Vincular de novo". | Revisão do código |
| 36 | Aparelho | Sem ajuda sobre nível de proteção, permissões, código offline e desvincular x apagar. | H10 | Média | `HelpButton` com quatro perguntas. | `guardian_device_detail*.png` |
| 37 | Aparelho | Confirmação de desvincular não dizia quando vale. | H1 | Baixa | "Vínculo revogado. O aparelho deixa de ser controlado ao sincronizar." | Revisão do código |
| 38 | Aparelhos | Um cartão com borda por aparelho e botão flutuante cobrindo a lista. | H8 | Baixa | Lista agrupada, botão na página e atalho na barra. | `guardian_devices*.png` |
| 39 | Aparelhos | Aparelho sem conexão há horas sem destaque na lista; regras pendentes invisíveis. | H1, H4 | Baixa | Mesmo estado de conexão do painel (atenção depois de 3 h) e "Regras aguardando o aparelho". | Revisão do código |
| 40 | Código offline | Erro "Não foi possível calcular o código" sem o que fazer; título repetido fora da moldura da folha. | H9, H4 | Baixa | Mensagem com o que fazer; folha padrão (`showAppSheet`). | "codigo offline mostra o codigo do momento e a contagem"; `guardian_offline_code*.png` |
| 41 | Nome da criança | Campo sem marca de obrigatório nem limite visível. | H5 | Baixa | `AppTextField(isRequired:, helper: "Até 40 caracteres.")`. | "nome longo demais mostra o erro sem enviar" |

Total: 2 de gravidade alta, 21 média e 18 baixa.

Testes acrescentados: capturas claras e escuras do Início (liberado, bloqueado, sem aparelho),
da casca com o aviso de alerta, da vinculação (código e pedido), do detalhe, da lista e do código
offline; fonte 2× e `expectAccessible` no Início, na casca, na vinculação, no detalhe e na lista.

## Pendências

- Em aparelho real: o aviso de alerta com TalkBack (fica até ser dispensado), a vibração das
  confirmações, "remover animações" e o momento do pedido de notificações logo depois da
  primeira aprovação.
- No teste da casca, as abas são páginas de teste e o contraste é conferido nas telas reais
  (Início, vinculação, aparelho); o aviso usa os papéis de fundo invertido do Design System.
- Dependem de outras funcionalidades: `CopyShareButtons` (acesso) ainda usa o botão contornado
  do Material; `AlertVisual` (alertas) ainda usa `Icons`. Quando migrarem, a vinculação e o
  painel acompanham sem mudança aqui.
- Sugestões para o Design System: linha de ação destrutiva com andamento (`AppListRow` com
  `destructive` e `busy`), aviso flutuante no topo para alertas em tempo real (`AppToast`),
  tom de botão para fundo invertido e um ícone de bateria sem o raio de carregamento.
