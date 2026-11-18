# Acesso, configurações e primeiro uso

Telas: boas-vindas (escolha do papel do aparelho), folha do servidor, porta de entrada do
responsável, criar conta, entrar, recuperar acesso, chave de recuperação, painel bloqueado,
pedido de senha para operações administrativas, aba Mais, conta e senha (nome, nova chave),
trocar senha, excluir conta, sessões conectadas, bloqueio do painel, dados e privacidade e
registro de alterações. Perfil: responsável (as boas-vindas valem para os dois aparelhos).

Funcionalidades: `onboarding`, `server_config`, `authentication`, `settings` e `user_role` (sem
tela própria).

## Heurísticas consideradas

- **H1 Visibilidade do estado:** toda operação mostra andamento no lugar em que foi pedida
  (botão ocupado, indicador na linha da sessão sendo encerrada, do nome sendo salvo e do ajuste
  de privacidade); a folha do servidor diz "Conferindo se há um servidor ParentaLynx nesse
  endereço…"; as confirmações aparecem só depois de concluídas e dizem o efeito ("Senha alterada.
  Os outros celulares conectados precisam entrar de novo."); pendências da aba Mais aparecem com
  ícone em tom de atenção e o texto do que falta.
- **H2 Mundo real:** "papel deste aparelho" (e não "modo"), "Tentativa recusada", "Acesso à
  conta" no lugar de códigos internos do registro, IP rotulado, explicações de cada tempo de
  bloqueio.
- **H3 Controle e liberdade:** trocar o servidor na porta de entrada, trocar o papel do
  aparelho, "Entrar com outra conta" no painel bloqueado, cancelar em todos os diálogos, folha
  com "Fechar", desistir de reduzir o histórico.
- **H4 Consistência:** formulários com `AppTextField`/`AppPasswordField`, diálogos com campo no
  mesmo padrão do `showConfirmDialog`, listas em `AppListGroup`, erros em `AppBanner` com título
  da operação, mesma mensagem de senha recusada e de espera em todo o fluxo.
- **H5 Prevenção de erros:** campos obrigatórios marcados, exemplos e formatos antes do erro
  (e-mail, chave, endereço), requisitos da senha visíveis antes de digitar, confirmação
  destrutiva com consequência (sair, encerrar sessão, entrar com outra conta, reduzir histórico),
  palavra digitada para excluir a conta, botões ocupados contra toque duplo.
- **H6 Reconhecimento:** de quem é a conta no painel bloqueado, na aba Mais, na confirmação de
  saída e na exclusão; servidor em uso visível antes da escolha; valor atual de cada ajuste.
- **H7 Eficiência:** prazos de histórico em atalhos (chips), "próximo" do teclado que segue de
  campo em campo, atalhos de "Apagar dados" direto para Aparelhos e Conta.
- **H8 Estética e minimalismo:** marca no primeiro acesso, hierarquia por cabeçalho e seções,
  sem cartão por item nem bordas, ajuda escondida atrás do "?" até ser útil.
- **H9 Erros:** cada erro diz qual operação falhou, o motivo, o que continua valendo ("Nada foi
  alterado.", "A senha anterior continua valendo.", "Nada foi apagado.") e o que fazer.
- **H10 Ajuda:** "?" em criar conta (o que a senha protege, chave, outro responsável) e em
  recuperar acesso (onde está a chave, perdi a chave e a senha, o que muda), passos "Como
  começar", aviso de controle transparente, listas do que é e do que nunca é coletado.

## Problemas encontrados e soluções

| # | Tela | Problema | Heurística | Gravidade | Solução | Verificação |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Boas-vindas | Ícone genérico de família em quadrado azul e cartões com borda: aparência de modelo pronto. | H8, H4 | Média | `BrandLockup`, cabeçalho "Primeiro acesso" e as duas escolhas em um `AppListGroup`. | `onboarding_welcome`, `onboarding_welcome_escuro` |
| 2 | Boas-vindas | O servidor só aparecia como "Configurar servidor" no rodapé; sem ele, tocar em um papel abria a folha de surpresa. | H1, H5 | Média | Seção "Servidor" com o endereço em uso ou "Servidor não configurado" + "Pendente", antes da escolha. | `sem servidor configurado pede o endereco antes de escolher` |
| 3 | Boas-vindas | Falha ao gravar o papel aparecia só em aviso passageiro, com a mensagem crua. | H9 | Média | `AppBanner` "Não foi possível definir o papel deste aparelho" + motivo, até a próxima tentativa. | `falha do lado nativo e mostrada e o modo nao muda` |
| 4 | Boas-vindas | Indicador da escolha em andamento sem nome para o leitor de tela. | H1 | Baixa | Indicador "Gravando a escolha"; a outra opção e o servidor ficam inativos. | `boas-vindas segue as diretrizes de acessibilidade` |
| 5 | Folha do servidor | Campo sem marca de obrigatório e sem formato; erro "Não foi possível falar com o servidor nesse endereço" + texto técnico, sem dizer se algo mudou. | H5, H9 | Média | `AppTextField` obrigatório com o formato no apoio; durante a conferência o apoio diz o que está acontecendo; erros por tipo (sem conexão, outro servidor) com o que fazer e "Nada foi alterado." | `server_config_test` (dois casos), `folha do servidor: explica o formato e mostra a falha sem gravar`, `onboarding_server_sheet` |
| 6 | Folha do servidor | Sem botão de fechar visível. | H3 | Baixa | `AppSheetFrame` com "Fechar". | `onboarding_server_sheet` |
| 7 | Porta de entrada | Escudo genérico, passos desenhados à mão, botão contornado. | H4, H8 | Baixa | Marca, `AppButton` primário e secundário, `StepList` "Como começar". | `guardian_sign_in`, `guardian_sign_in_escuro` |
| 8 | Porta de entrada | Servidor digitado errado só era corrigido voltando à escolha de papel. | H3 | Média | Linha "Servidor" abre a folha ali mesmo (`ServerConfigBloc` na rota). | `porta de entrada mostra os caminhos, o servidor e a troca de papel` |
| 9 | Porta de entrada | Sessão encerrada e conta excluída com o mesmo aviso amarelo e texto vago. | H1, H9 | Média | `AppBanner` "Sessão encerrada" (atenção, com o motivo provável) ou "Conta excluída" (confirmação do que foi apagado). | `auth_flow_test` (aviso de sessão encerrada) |
| 10 | Porta de entrada | "Voltar para a escolha de modo": termo diferente das boas-vindas e sem andamento. | H2, H4 | Baixa | "Trocar o papel deste aparelho", com indicador e falha que diz o que não foi feito. | `guardian_sign_in` |
| 11 | Criar conta | Obrigatórios sem marca, e-mail sem exemplo. | H5 | Média | `isRequired`, exemplo `maria@exemplo.com`, apoio de cada campo. | `guardian_register` |
| 12 | Criar conta, recuperar, trocar senha | Estado dos requisitos da senha só em ícone e cor; o leitor de tela não sabia o que faltava. | H5 | Baixa | Requisitos visíveis antes de digitar, com "atendido/pendente/corrija" lido; barra do Design System. | `registro segue as diretrizes de acessibilidade` |
| 13 | Criar conta | Erro geral no topo do formulário, fora da vista de quem tocou em "Criar conta" no fim da página. | H9, H1 | Média | `AppBanner` "Não foi possível criar a conta" logo acima do botão, anunciado ao aparecer. | `registro mostra o erro de e-mail ja usado no campo` |
| 14 | Criar conta | Erros de nome e e-mail não sumiam ao corrigir. | H9 | Baixa | Edição de nome e e-mail também limpa o erro do campo. | `registro valida a senha antes de enviar` |
| 15 | Formulários com senha | O "próximo" do teclado parava no botão de mostrar a senha e fechava o teclado. | H7 | Média | `focusNextAfterPassword` pula o botão (ajuste local; ver pendências do Design System). | `registro: o proximo do teclado passa da senha para a confirmacao` |
| 16 | Criar conta | Sem explicação do que a senha protege nem do passo seguinte. | H10 | Baixa | "?" com três respostas, "Passo 1 de 3" e "Em seguida, você guarda a chave de recuperação…". | `guardian_register` |
| 17 | Chave de recuperação | Botão "Continuar" inativo sem dizer por quê; caixa de seleção solta. | H1, H5 | Média | `AppCheckboxRow` "Guardei a chave…" com "Necessário para continuar"; o botão só libera depois. | `chave de recuperacao: copiar e confirmar`, `app_router_test` |
| 18 | Chave de recuperação | O leitor de tela lia a chave como uma palavra, difícil de anotar ouvindo. | H6 | Média | Rótulo soletrado em grupos ("R K, 7 H 2 K D…"). | `chave de recuperacao segue as diretrizes de acessibilidade` |
| 19 | Chave de recuperação | Falha ao compartilhar com mensagem genérica. | H9 | Baixa | "Não foi possível abrir o compartilhamento. Copie a chave ou anote em papel." | Revisão de código |
| 20 | Chave de recuperação (configurações) | A tela não dizia que uma chave nova tinha sido gerada. | H1 | Baixa | Sobretítulo "Nova chave gerada". | `nova chave de recuperacao pede a senha e mostra a chave uma vez` |
| 21 | Painel bloqueado | A conta aparecia no meio da frase. | H6 | Média | Linha com avatar, nome (quando conhecido) e e-mail. | `tela de bloqueio mostra a conta gravada`, `guardian_unlock` |
| 22 | Painel bloqueado | Não dizia por que o painel bloqueou. | H2, H10 | Baixa | "Por segurança, o painel pede a senha… ao abrir o app e depois de um tempo sem uso." | `guardian_unlock` |
| 23 | Painel bloqueado | Sem saída além da senha e da recuperação. | H3 | Média | "Entrar com outra conta", com confirmação destrutiva e consequência. | `tela de bloqueio: entrar com outra conta pede confirmacao e sai da conta` |
| 24 | Pedido de senha | `AlertDialog` do Material, diferente das confirmações do Design System. | H4 | Média | Mesmo padrão do `showConfirmDialog` (ícone, título, explicação, campo, ações empilhadas), botão ocupado. | `guardian_elevation`, `guardian_elevation_escuro` |
| 25 | Pedido de senha | Não dizia o que acontece ao cancelar; espera em "2min" enquanto o resto do app dizia "2 minutos". | H3, H4 | Baixa | "Se você cancelar, nada é alterado."; mesma mensagem do desbloqueio. | `pedido de senha: recusa no campo e libera com a senha certa`, `pedido de senha: cancelar nao libera a operacao` |
| 26 | Entrar | Erro sem dizer qual operação falhou, no topo. | H9 | Baixa | `AppBanner` "Não foi possível entrar" + motivo (como o tempo de espera do bloqueio por tentativas), junto ao botão. | `login mostra bloqueio por tentativas com o tempo de espera` |
| 27 | Entrar | Campos sem marca de obrigatório e sem exemplo. | H5 | Baixa | `isRequired` e exemplo. | `guardian_login` |
| 28 | Recuperar acesso | Falha sem dizer que a senha anterior continua; consequências só no fim, sem título. | H9, H5 | Média | Aviso "Ao recuperar" antes da ação; erro "Não foi possível recuperar o acesso" + "A senha anterior continua valendo." | `recuperacao recusada diz o motivo e que a senha anterior continua` |
| 29 | Recuperar acesso | Sem ajuda para "onde está a chave" ou "perdi a chave". | H10 | Média | "?" com três respostas, inclusive a honesta: sem chave e sem senha não há como recuperar. | `guardian_recover` |
| 30 | Recuperar acesso | Regra de digitação da chave não explicada. | H5 | Baixa | Apoio "Letras e números em grupos de cinco. Espaços e minúsculas são aceitos." | `guardian_recover` |
| 31 | Mais | Cartão por grupo com borda, linhas do Material, conta dentro de outro cartão. | H8, H4 | Média | `AppPageHeader` com a conta, seções com `AppListGroup` e ícones em `AppIconTile`. | `guardian_more`, `guardian_more_escuro` |
| 32 | Mais | Pendências destacadas só pela cor do texto; plural "pedido(s)". | H1 | Baixa | Ícone em tom de atenção + texto com quantos e o que fazer, plural correto. | `pedido de tempo esperando destaca o item com o texto do que falta` |
| 33 | Mais | Sair da conta sem consequência nem a conta; botão contornado solto. | H3, H6 | Média | Confirmação destrutiva com o e-mail para voltar; linha "Sair da conta" no fim, em tom de perigo. | `sair da conta pede confirmacao e encerra a sessao` |
| 34 | Conta e senha | Seções em cartões com botões contornados; exclusão como botão vermelho solto. | H8, H4 | Baixa | Listas agrupadas; exclusão em seção própria com "Não pode ser desfeito". | `guardian_conta`, `guardian_conta_escuro` |
| 35 | Conta e senha | Nova chave: senha errada fechava o diálogo e mostrava aviso passageiro; era preciso reabrir e digitar de novo. | H9, H3 | Média | O pedido continua aberto com a recusa no campo; consequência "A chave atual deixa de valer…". | `nova chave de recuperacao pede a senha e mostra a chave uma vez` |
| 36 | Conta e senha | Trocar o nome sem andamento; falha genérica. | H1, H9 | Baixa | Indicador na linha; "Não foi possível alterar o nome. O nome anterior continua." | `troca o nome com a regra de tamanho e atualiza a conta` |
| 37 | Trocar senha | Senha atual errada aparecia como erro geral, longe do campo. | H9 | Média | Erro no campo "Senha atual". | `settings_blocs_test` (troca de senha), `troca de senha mostra a recusa do servidor e fecha ao concluir` |
| 38 | Trocar senha | Efeito nos outros aparelhos só no subtítulo; confirmação "Senha alterada." sem o efeito. | H1 | Baixa | Aviso "Depois da troca" antes da ação e confirmação com o efeito. | `troca de senha mostra a recusa do servidor e fecha ao concluir` |
| 39 | Excluir conta | Falha de conexão aparecia no campo da senha, como se a senha estivesse errada, sem dizer que nada foi apagado. | H9 | Alta | Recusa de senha no campo; demais falhas em `AppBanner` "A conta não foi excluída… Nada foi apagado." | `exclusao sem conexao avisa que nada foi apagado`, `settings_blocs_test` |
| 40 | Excluir conta | Não mostrava qual conta seria excluída. | H6 | Média | Subtítulo com o e-mail da conta (o BLoC lê a conta atual). | `exclusao sem conexao avisa que nada foi apagado` |
| 41 | Excluir conta | Só o voltar como saída; indicador próprio no botão. | H3, H1 | Baixa | `AppButton.danger` ocupado e "Cancelar". | `guardian_excluir_conta` |
| 42 | Sessões | Sem andamento ao encerrar; dava para tocar em outro "Encerrar" durante a operação. | H1, H5 | Média | O BLoC guarda a sessão em encerramento: indicador na linha e botões inativos. | `settings_blocs_test` (sessões), `sessoes conectadas: encerra a sessao de outro aparelho` |
| 43 | Sessões | Confirmação com "Encerrar" e sem consequência. | H3 | Baixa | "Encerrar sessão" + "Se você não reconhece esse aparelho, troque também a senha". | `sessoes conectadas: encerra a sessao de outro aparelho` |
| 44 | Sessões | Indicador de tela inteira e erro genérico. | H1, H9 | Baixa | `SkeletonListGroup`, `ErrorState.fromError` ("as sessões"), `StateSwitcher`. | `guardian_sessoes` |
| 45 | Bloqueio do painel | Opções sem explicar a diferença; explicação longa em um aviso. | H2, H8 | Baixa | `AppRadioRow` com detalhe por opção, explicação no subtítulo, "Bloqueio imediato" separado. | `bloqueio do painel grava o tempo escolhido e bloqueia agora`, `guardian_bloqueio` |
| 46 | Dados e privacidade | Reduzir o prazo do histórico apagava dados antigos sem nenhum aviso. | H5 | Alta | Confirmação destrutiva só ao reduzir ("O que for apagado não pode ser recuperado"); aumentar grava direto. | `privacidade: encurtar o historico pede confirmacao antes de gravar`, `privacidade: aumentar o historico grava sem confirmacao` |
| 47 | Dados e privacidade | Prazo escolhido em diálogo, sem ver as opções. | H7, H6 | Baixa | `AppChoiceChips` com o valor atual marcado. | `guardian_privacidade` |
| 48 | Dados e privacidade | Ajustes sem andamento; falha genérica. | H1, H9 | Baixa | "Salvando" na seção, opções inativas, falha diz que o valor anterior continua. | `privacidade: aviso de pouco tempo escolhido na folha de opcoes` |
| 49 | Dados e privacidade | "Apagar dados" só dizia onde ir. | H6, H7 | Baixa | Linhas que levam direto a Aparelhos vinculados e a Conta e senha. | `guardian_privacidade` |
| 50 | Registro de alterações | Sem descrição, aparecia o código interno ("auth.login"). | H2 | Média | Assunto em palavras comuns ("Acesso à conta", "Tentativa recusada"…). | `registro de alteracoes carrega os registros mais antigos` |
| 51 | Registro de alterações | Tentativas recusadas misturadas às demais. | H1, H6 | Média | Ícone de atenção em tom de perigo e texto explicando o destaque. | `guardian_registro` |
| 52 | Registro de alterações | IP sem rótulo; carregamento, erro e "carregar mais" fora do padrão. | H2, H1 | Baixa | "IP …", `SkeletonListGroup`, `ErrorState`, botão ocupado, `AppBanner` com "Tentar de novo". | `guardian_registro` |

Total: 52 problemas, 2 de gravidade alta, 24 média e 26 baixa.

Cada tela principal tem captura nos temas claro e escuro (`*_escuro.png`), teste com fonte 2×
sem erros de layout e o `expectAccessible` (toque de 48, rótulos, contraste). Todas as
funcionalidades passam em `test/architecture/design_system_test.dart`, sem importar os caminhos
antigos.

## Pendências

- **Aparelho real:** o "próximo" do teclado com teclados do Android, o preenchimento automático
  de gerenciadores de senha, a leitura da chave soletrada no TalkBack e a folha de
  compartilhamento.
- **Design System** (pedidos para o time do Design System, contornados dentro das
  funcionalidades):
  - `AppPasswordField` sem `focusNode` e com o botão de mostrar a senha na ordem do "próximo";
    hoje `focusNextAfterPassword` pula o botão.
  - Diálogo com campo no padrão do `showConfirmDialog` (`FormDialogFrame`, em
    `authentication/presentation/widgets/auth_widgets.dart`, usado pelo pedido de senha, pela
    nova chave e pelo nome).
  - Andamento dentro de uma linha (`InlineProgress`) e estado ocupado no `AppListRow`.
  - `AppSection` só mostra o subtítulo quando há título.
  - Um componente para segredos e códigos (fonte de largura fixa, grupos): a chave quebra em
    "…-4MNP8" porque o texto não quebra entre hífen e número; serviria também ao código de
    vinculação.
- A aba Mais leva a telas de outras funcionalidades (vincular aparelho, aparelhos, pedidos de
  tempo, preferências de notificação), avaliadas nos arquivos dessas funcionalidades.
