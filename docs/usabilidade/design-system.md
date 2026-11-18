# Design System e tela de bloqueio nativa

Componentes compartilhados por todas as telas (`app/lib/shared/design_system/`) e a tela de
bloqueio nativa do Android (`BlockActivity`), que a criança vê quando uma regra age sobre um app.
Perfil: os dois.

## Heurísticas consideradas

| Heurística | Como o Design System atende |
| --- | --- |
| H1 Visibilidade do estado | `SyncStatusLine` dá nome e forma únicos aos estados de uma regra entre o painel e o aparelho (aplicado, aguardando o aparelho, enviando, sem conexão, falha); `PolicySyncStatusView` só mostra "aplicadas" depois da confirmação do aparelho. `AppButton(busy:)` mostra a operação em andamento. Avisos, erros e estados de sincronização são anunciados pelo leitor de tela (`liveRegion`). |
| H2 Mundo real | Rótulos padrão em linguagem comum ("Aguardando o aparelho confirmar", "Aparelho sem conexão"); ícones por significado em `AppIcons`. |
| H3 Controle e liberdade | `showConfirmDialog` separa ação destrutiva (vermelha, com a consequência) de reversível; folhas com botão "Fechar"; `showAppSnackBar` aceita "Desfazer". |
| H4 Consistência | Uma cor por significado (`AppColors`, `Tone`), um estilo de ícone, um componente por padrão; regras conferidas por teste em todas as funcionalidades. |
| H5 Prevenção de erros | Botão ocupado ignora toques (sem envio duplo); campos com obrigatório marcado e formato esperado visível (`isRequired`, `hint`, `helper`); confirmação nomeia a ação ("Desvincular", não "OK"). |
| H6 Reconhecimento | `AppPageHeader` com o contexto (criança, aparelho); rótulos de campo sempre visíveis. |
| H7 Eficiência | `AppChoiceChips` e o seletor de duração com valores prontos. |
| H8 Minimalismo | Seções separadas por espaço, listas agrupadas em um único painel com contorno fino, sem sombras e sem fundos coloridos; cor só no que é interativo e nos estados. |
| H9 Erros | `ErrorState` e `AppBanner` seguem o modelo "o que aconteceu, o que foi salvo, o que fazer", com ação de recuperação. |
| H10 Ajuda | `HelpButton`/`showHelpSheet` com perguntas e respostas curtas, ao lado do que explicam. |

## Problemas encontrados e soluções

| # | Onde | Problema | Heurística | Gravidade | Solução | Verificação |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Tema | Visual de template: índigo gerado automaticamente, Roboto, todo conteúdo em cartão branco com borda. | H8, H4 | Média | Identidade "Lince": petróleo, neutros de areia, Manrope, painéis sem borda, listas agrupadas. | Capturas `ds_*.png` |
| 2 | Botões | O botão tonal (lilás claro com texto cinza) parecia desabilitado ("Pausar agora", "Sincronizar agora"). | H1, H4 | Alta | Ação secundária em petróleo claro com texto escuro (contraste alto); desabilitado em cinza neutro, claramente diferente. | `ds_acoes_*.png`, contraste no teste de acessibilidade |
| 3 | Botões | Operação em andamento deixava o botão com cara de desabilitado. | H1 | Média | `busy` mantém a cor, mostra o indicador e ignora toques; leitor de tela ouve "em andamento". | Catálogo |
| 4 | Mensagens | Falha inesperada mostrava "Algo deu errado. Tente de novo.". | H9 | Média | "Ocorreu um erro inesperado e a operação não foi concluída. Tente de novo."; resposta em formato inesperado pede para conferir se a mudança aparece. | `core/errors/app_failure.dart` |
| 5 | Erros de carregamento | Estado de erro genérico sem dizer o que falhou. | H9 | Média | `ErrorState.fromError(erro, subject: ...)`: "Não foi possível carregar os relatórios" + motivo + "Tentar de novo". | Catálogo (`ds_retorno_*`) |
| 6 | Sincronização | Pendente e aplicado tinham o mesmo formato de aviso; offline aparecia só como detalhe. | H1 | Alta | `SyncStatusLine` com estados distintos (ícone, cor e texto); offline diz que as regras anteriores continuam valendo até o aparelho voltar. | `policy_sync_status_view.dart`, testes do painel e das regras |
| 7 | Campos | O rótulo flutuante ficava na cor da marca mesmo sem foco e com erro; obrigatório não era indicado. | H5, H4 | Baixa | Rótulo sempre visível, cinza em repouso, petróleo com foco, vermelho com erro; asterisco + "obrigatório" para o leitor de tela. | `ds_acoes_*.png` |
| 8 | Fonte ampliada | A escala de fonte era limitada a 1,6×, abaixo do máximo do Android. | Acessibilidade | Média | Limite em 2× (máximo do Android); componentes quebram linha; números no anel e nas métricas diminuem para caber em uma linha. | Teste "fonte no maior tamanho" do catálogo |
| 9 | Estados por cor | Etiquetas e avisos dependiam da cor para o significado em alguns usos. | Acessibilidade, H4 | Média | Todo componente com tom mostra ícone e texto; `StatusBadge` com ícone padrão do tom. | Catálogo |
| 10 | Descanso | Hora de dormir e pausa usavam o mesmo vermelho de erro. | H2, perfil da criança | Média | Tom `rest` (anil) para descansos combinados; vermelho só para erro e destrutivo. | `ds_crianca_*.png` |
| 11 | Ícones | Mistura de estilos (contornado, preenchido, arredondado) e o mesmo conceito com ícones diferentes. | H4 | Baixa | `AppIcons`: um estilo, um ícone por significado; teste recusa `Icons.*` nas telas. | `design_system_test.dart` |
| 12 | Tela de bloqueio nativa | Título "App bloqueado"/"Limite diário atingido" em fundo índigo antigo, tom punitivo; "Liberação às 07:00". | H2, perfil da criança | Média | Fundo petróleo (anil nos descansos), Manrope, textos que explicam o motivo e quando volta ("O tempo de hoje acabou", "Hora de descansar", "Volta a funcionar amanhã às 07:00"); ícone de pausa para a pausa do responsável. | Compilação do APK; validação em aparelho pendente |
| 13 | Tela de bloqueio nativa | "Pedido registrado. Seu responsável será avisado." prometia um aviso imediato mesmo offline. | H1 | Média | "Pedido registrado. Seu responsável recebe o aviso assim que o celular estiver conectado." | Revisão do fluxo (o pedido vai para a fila do agente) |
| 14 | Ícone do app | Escudo com relógio no índigo antigo, sem relação com a marca. | H4, identidade | Baixa | Lince da marca em vetor, com versão monocromática para ícones temáticos. | Compilação do APK |
| 15 | Visual geral | Aparência de interface gerada: fundos pastel em botões, avisos, etiquetas e ícones; cantos de 20 a 28; pílulas; sobretítulos em maiúsculas; pesos 700 e 800 em quase todos os títulos; fundo de areia. | H8, H4 | Média | Revisão da [ADR 0003](../adr/0003-revisao-visual-sobriedade.md): neutros grafite, contorno fino nas superfícies, cor só em ícones e textos de estado, raios de 8 a 16, títulos em 600, sobretítulo em caixa normal. | Capturas de referência regeneradas em todas as telas |
| 16 | Botões | O secundário em petróleo claro (solução do item 2) disputava atenção com o primário e somava mais um fundo colorido à tela. | H8, H4 | Baixa | Secundário contornado sobre a superfície, com texto na cor do texto principal; o primário é o único botão preenchido. Desabilitado continua em cinza. | `ds_acoes_*.png` |
| 17 | Campos | O rótulo ficava no recorte da borda, desenho padrão do Material. | H6 | Baixa | Rótulo acima do contorno, sempre visível e anunciado como nome do campo pelo leitor de tela. | Teste de acessibilidade dos formulários |
| 18 | Listas | Um quadrado colorido atrás de cada ícone de linha e as letras dos apps em petróleo transformavam as listas em um mosaico. | H8 | Baixa | Ícone de linha sem fundo, em cinza, colorido só para confirmação, atenção e erro; letras dos apps em quadrado neutro. | `ds_conteudo_*.png`, regras, relatórios |
| 19 | Painel do responsável | O anel do tempo ocupava boa parte da primeira tela e o avatar repetia o nome da criança. | H8 | Baixa | Tempo restante em número com barra de uso; cabeçalho sem avatar. | `dashboard_*.png` |
| 20 | Tela de bloqueio nativa | Degradê, cantos de 20 a 28 e círculo translúcido destoavam do app. | H4 | Baixa | Fundo sólido (petróleo escuro ou anil escuro nos descansos), cantos de 12 a 16, ícone em quadro contornado, título em Bold. | Compilação do APK; validação em aparelho pendente |

## Pendências

- Validar a tela de bloqueio nativa e o ícone em aparelhos reais (tamanhos de tela, fonte do
  sistema ampliada, TalkBack).
