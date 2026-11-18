# Experiência da criança e navegador gerenciado

Telas: entrada (consulta do vínculo e agente sem resposta), vincular este aparelho (código,
espera da confirmação, ativação, aviso de vínculo removido), o que este app faz (transparência),
permissões do controle (configuração inicial e depois), tela inicial (tempo livre, pouco tempo,
tempo esgotado, hora de dormir, pausa do responsável, permissão desligada, sem limite, regras
liberadas, pedido de tempo), folha "Pedir mais tempo", área do responsável (senha, código offline,
operações) e navegador gerenciado (início, site barrado, filtro sem resposta, página que não
abriu, indisponível). Perfil: criança.

Toda a área da criança fica dentro de `AppExperienceScope(experience: AppExperience.child)` (na
casca `childShellRoute`), inclusive folhas e diálogos; o navegador já usa o perfil da criança no
`BrowserApp`.

## Heurísticas consideradas

- **H1 Visibilidade:** o tempo que resta é o único número em destaque ("1h 20min", com a frase
  completa para o leitor de tela); o estado do último pedido de tempo fica logo abaixo do botão;
  "Regras em dia · Atualizadas há 2 min"; a próxima pausa aparece antes de começar; a espera da
  vinculação diz que a tela muda sozinha; as permissões mostram "2 de 3 obrigatórias ligadas".
- **H2 Mundo real:** sem "sincronizar", "suspensão" ou contagem com segundos; "pausa" só quer
  dizer aparelho em pausa; nomes das permissões iguais aos do Android, cada um com o porquê.
- **H3 Controle e liberdade:** a folha de pedido fecha sem enviar; cancelar a espera e sair das
  permissões pedem confirmação com "Continuar esperando"/"Voltar e ligar"; a área do responsável
  diz "Chegou aqui sem querer? É só voltar."
- **H4 Consistência:** mesmos componentes do resto do app; restrições sempre com o tom de descanso
  ou neutro (nunca vermelho), inclusive no navegador.
- **H5 Prevenção de erros:** pedidos com valores prontos e sem envio duplo (`busy`); aviso de
  pedido ainda sem resposta; formato do código sempre visível e "Vincular" só com o código
  completo; operações que retiram proteção com confirmação e consequência.
- **H6 Reconhecimento:** nome do responsável nas regras, no pedido e na transparência; apps
  sempre liberados com ícone e nome; dia da semana acima da saudação (as regras mudam por dia).
- **H7 Eficiência:** "Pedir mais tempo" a um toque; apps sempre liberados abrem com um toque;
  linhas de permissão pendente abrem direto a tela do Android.
- **H8 Minimalismo:** um herói (o tempo), uma ação principal, formas diferentes por assunto (anel,
  grade de apps, lista com barras, frases de regra, grupos de linhas) em vez de uma pilha de
  cartões iguais; uso de hoje mostra 3 apps e "Ver todos".
- **H9 Erros:** cada falha diz o que houve e o próximo passo (agente sem resposta, pedido não
  enviado, filtro sem resposta, permissão desligada, relógio não conferido).
- **H10 Ajuda:** transparência em frases curtas; passo a passo de cada permissão; divulgação da
  acessibilidade antes de abrir a tela do Android; onde achar o código offline.

## Problemas encontrados e soluções

| # | Tela | Problema | Heurística | Gravidade | Solução | Verificação |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Início | Tempo esgotado com anel **vermelho** e faixa ocre repetindo o aviso: clima de castigo e mensagem duplicada. | H4, H1, H8 | Alta | Painel de descanso (`Tone.rest`) com o motivo, quando volta e o que continua funcionando; o anel some. O mesmo padrão para hora de dormir, pausa do responsável e permissão desligada (neutro). | `child_screens_test`: "limite atingido…" (claro e escuro), "hora de dormir…"; capturas `child_home_locked*`, `child_home_bedtime` |
| 2 | Início | Tempo "1:20:00" lido como hora do relógio e mudando a cada segundo (pressa). | H2, H8 | Média | "1h 20min" com unidades menores, minutos arredondados para cima; frase completa no leitor de tela. | `child_mode_logic_test`: "tempo restante…", "os minutos restantes arredondam…"; `bySemanticsLabel` em "liberado…" |
| 3 | Início | "Em pausa até 18:00" para regras **liberadas**: a mesma palavra para o contrário do aparelho em pausa. | H2, H4 | Média | "Regras liberadas até 18:00 · Maria liberou o limite de tempo e os horários de pausa." | logic: "suspensao de regras…" |
| 4 | Início | "Sincronizar agora", "Última sincronização" (termos internos). | H2 | Média | "Atualizar agora"; "Regras em dia · Atualizadas há 2 min"; sem internet: "As regras continuam valendo". | screens: "atualizar agora avisa o resultado"; logic: "estado das regras…" |
| 5 | Início | Faixa de atenção oferecia "Ver permissões" até para relógio não conferido. | H9 | Média | Ação só para problemas de permissão; o relógio diz o que fazer ("Deixe a data e a hora automáticas"). | logic: "so problemas de permissao…" |
| 6 | Início | Bloqueio por permissão desligada só dizia "Chame Maria", mas ele sai ao religar a permissão. | H9 | Média | "Ligue de novo para liberar os apps, ou peça ajuda a Maria" + "Ver permissões" no painel. | logic: "permissao desligada orienta…" |
| 7 | Início | "Pedir mais tempo" sem limite (não muda nada) e como ação principal na hora de dormir. | H2, H8 | Média | Some sem limite; ação de apoio nas pausas; principal com tempo contando ou esgotado; ausente na permissão desligada. | screens: "sem limite nao oferece…", "hora de dormir…" (variante secundária) |
| 8 | Início | Estado do pedido escondido em um cartão no meio da pilha. | H1 | Média | Último pedido logo abaixo do botão: quanto, quando, etiqueta ("Esperando a resposta", "Aprovado: mais 30min"…) ou "guardado, vai quando houver internet". | screens: "liberado…" ("Pedido de 30min", "Esperando a resposta") |
| 9 | Início | Pilha de cartões iguais com borda; dois botões grandes competindo; botão da área do responsável no topo. | H8, H4 | Média | Formas diferentes por assunto; navegador seguro virou linha; área do responsável no grupo "Sobre o controle" ("Só com a senha do responsável"). | capturas `child_home`, `child_home_escuro` |
| 10 | Início | Carregamento com tela em branco e barras de progresso nos cartões. | H1 | Baixa | Esqueletos com a forma da tela e de cada seção; troca com `StateSwitcher`. | revisão (estado de poucos quadros) |
| 11 | Entrada, Início | Agente sem resposta em estado de erro genérico. | H9 | Média | `ChildProblemView`: calmo, "Tente de novo; se continuar, reinicie o aparelho". | `child_routing_test`: "falha ao consultar o agente…" |
| 12 | Início | Com fonte 2× o número do anel encolhe sem repetir o valor. | H1 | Baixa | Com fonte ampliada, "Restam 1h 20min para usar hoje." em texto. | screens: "funciona com a fonte no maior tamanho" |
| 13 | Início | Ícones das regras sem significado de cor (bloqueio na cor de ação). | H4 | Baixa | Tom por assunto: descanso para pausas, neutro para bloqueios, sucesso para horário liberado. | capturas `child_home*` |
| 14 | Início | "Próxima pausa: começa às 21:00" em faixa genérica. | H1, H2 | Baixa | "Hora de dormir começa às 21:00." com o tom de descanso. | logic: "proxima pausa so aparece…" |
| 15 | Pedido de tempo | Falha de envio mostrada como erro do campo "Recado". | H9 | Média | Aviso próprio "O pedido não foi enviado" com a mensagem; o botão continua para tentar de novo. | screens: "falha ao enviar o pedido…" |
| 16 | Pedido de tempo | Nada avisava que já havia um pedido sem resposta. | H5 | Média | "Você já pediu 30min há 30 min e a resposta ainda não chegou…" | screens: "com um pedido sem resposta…" |
| 17 | Pedido de tempo | Folha sem cabeçalho padrão nem "Fechar"; nada sobre funcionar sem internet. | H3, H10 | Baixa | `showAppSheet` com título, para quem vai o pedido e "Fechar"; rodapé "Sem internet, o pedido fica guardado…". | screens: fecha sem enviar (`verifyNever`); captura `child_time_request_sheet` |
| 18 | Vincular | Formato do código só no marcador; botão habilitava antes da hora. | H5 | Média | Ajuda sempre visível ("8 letras e números…"); "Vincular" só com o código completo e o nome. | `link_page_test`: "formulario…", "o botao vincular so funciona…" |
| 19 | Vincular | Formulário desabilitado aparecia enquanto conferia um pedido guardado. | H1 | Baixa | "Conferindo este aparelho..." e troca suave para o código ou a espera. | `link_page_test` (todas as telas) |
| 20 | Vincular | Espera com barra indeterminada; falha de conexão não dizia se o pedido continuava. | H1, H9 | Média | Linha de estado: "Esperando a aprovação…/Esta tela muda sozinha" ou "Sem conexão… O pedido continua valendo". Número de confirmação lido dígito a dígito. | `link_page_test`: "espera mostra o numero…" (claro e escuro) |
| 21 | Vincular | Cancelar a espera sem a consequência destacada. | H5, H3 | Baixa | Consequência "será preciso digitar um código de novo"; "Continuar esperando". | `link_page_test`: "cancelar a espera pede confirmacao…" |
| 22 | Vincular | Vínculo removido em tom de alerta. | H4 | Baixa | Aviso informativo com ícone de desvincular, anunciado pelo leitor de tela. | `link_page_test`: "vinculo desfeito…" |
| 23 | Transparência | "O que este app NÃO vê" com o ícone de bloqueio (sinal de restrição). | H2, H4 | Média | Olho cortado em tom de sucesso; marcador por assunto em cada seção. | capturas `child_transparency*` |
| 24 | Transparência | Seis cartões com borda empilhados; sem saber o que vem depois. | H8, H1 | Baixa | Seções sobre o fundo; responsável com a inicial; "Primeiros passos · 1 de 2"; barra fixa "Entendi, continuar" com "Depois vêm as permissões". | `child_routing_test`; capturas `child_transparency*` |
| 25 | Permissões | Todos os passos como cartões grandes iguais, ligados ocupando o mesmo espaço. | H8 | Média | "Próximo passo" em destaque e lista compacta "Todas as permissões" (ligadas só com a etiqueta). | screens: "destacam o proximo passo…" (claro e escuro) |
| 26 | Permissões | Sem orientação do que fazer na tela do Android. | H10 | Média | Passo a passo por permissão ("Toque em…", "escolha ParentaLynx e ligue a opção", "volte para cá: esta tela confere sozinha"). | screens: `'Toque em "Ativar acessibilidade".'` |
| 27 | Permissões | "Concluir" desabilitado sem explicar por quê. | H1, H5 | Baixa | Barra fixa com "Ligue as permissões obrigatórias para concluir."; "Continuar mesmo assim" com confirmação e consequência. | screens: "continuar sem as obrigatorias pede confirmacao" |
| 28 | Área do responsável | Nada orientava a criança que chegou ali por engano. | H3 | Baixa | "Para entrar, é preciso a senha do responsável." e "Chegou aqui sem querer? É só voltar." | captura `child_guardian_area_password*` |
| 29 | Área do responsável | Desativar administrador e deixar de gerenciar sem dizer como voltar atrás. | H5 | Média | Consequência em cada confirmação; desvincular com consequência e, pelo código offline, quando o painel fica sabendo. | screens: "desvincular pede confirmacao com a consequencia" |
| 30 | Área do responsável | Indicador manual no "Desvincular"; não se via qual operação estava em andamento. | H1 | Baixa | `AppButton(busy:)` na operação em andamento; as outras ficam indisponíveis. | revisão; capturas `child_guardian_area*` |
| 31 | Navegador | Site barrado em ocre com a mão de "pare" (bronca). | H4 | Média | Tom neutro com ícone de site bloqueado, o motivo e "converse com o seu responsável". | `browser_page_test`: "site barrado…" (claro e escuro) |
| 32 | Navegador | Filtro sem resposta tratado como regra, sem "Tentar de novo". | H9 | Média | "Não deu para conferir este site" e ação principal "Tentar de novo" (o filtro confere de novo). | `browser_page_test`: "filtro sem resposta nao e uma regra…" |
| 33 | Navegador | Início com três faixas coloridas empilhadas. | H8 | Baixa | Um painel com marcadores (lista de sites, busca segura, histórico). | capturas `child_browser_start*` |

Total: 33 problemas (1 alta, 19 médias, 13 baixas). Todas as telas principais têm captura clara e
escura, teste com fonte 2× (sem estouro) e `expectAccessible` (área de toque, rótulos e contraste).

## Pendências

- Validar em aparelho real: ícones verdadeiros dos apps (os testes usam o ícone genérico),
  leitura com o TalkBack, a ida e volta pelas telas do Android nas permissões e o navegador com o
  WebView real (os testes usam um motor falso).
- "Pedir mais tempo" durante a hora de dormir ou a pausa do responsável: aprovar soma minutos à
  cota e não libera a pausa (regra do servidor). Ficou como ação de apoio; falta uma decisão de
  produto (por exemplo, um pedido de liberação).
- A tela de bloqueio nativa (Kotlin) segue o mesmo padrão, mas é tratada fora desta funcionalidade.
- Componentes para promover ao Design System, hoje compostos dentro das funcionalidades: o
  medalhão de ícone em círculo (tela inicial e navegador), a grade de apps (ícone + nome tocável) e
  o sobretítulo no `ChildHeader` ("Primeiros passos · 1 de 2").
