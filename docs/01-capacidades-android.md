# Análise de capacidades do Android por modo de instalação

Este documento foi escrito antes da implementação, como exige a especificação. Ele define o que o
ParentaLynx consegue garantir em cada modo de instalação, o que consegue apenas detectar e o que
não é possível. Todas as decisões de arquitetura do agente nativo derivam daqui.

A seção 9 registra o que foi validado na prática em emulador e o que permanece sem validação.

## 1. Resumo

Um aplicativo instalado normalmente no Android não tem autoridade para impedir a própria
desinstalação, bloquear as Configurações ou controlar todos os aplicativos. O que ele consegue é
**observar** qual app está em primeiro plano e **reagir** (tirar o app da tela e mostrar uma tela de
bloqueio). Isso é eficaz no uso comum, mas pode ser contornado por quem desativa as permissões.

O controle que o próprio sistema operacional impõe só existe quando o app é o **Device Owner**
(dono do dispositivo, modo "totalmente gerenciado"). Nesse modo o sistema suspende os aplicativos
bloqueados, impede a desinstalação e mantém o bloqueio mesmo se o nosso processo morrer.

Por isso o ParentaLynx trabalha com três níveis, do mais fraco ao mais forte, e informa em tela
(para a criança e para o responsável) em qual nível o dispositivo está e o que não é garantido nele.

| Nível | Como é obtido | Resumo |
| --- | --- | --- |
| **Padrão** | Instalação comum + permissões especiais concedidas na configuração | Contagem de tempo e bloqueio por interceptação. Contornável por quem desativa permissões ou desinstala. Toda adulteração detectável é comunicada ao responsável. |
| **Padrão + Administrador do dispositivo** | Nível padrão + ativação opcional como administrador | Igual ao padrão, mas a desinstalação exige desativar o administrador antes, e essa desativação gera alerta. |
| **Device Owner** | Provisionamento em aparelho recém-restaurado (QR code ou `adb`) | Bloqueio feito pelo sistema (suspensão de apps), desinstalação impedida, modo de segurança e restauração de fábrica pelas Configurações bloqueados, relógio protegido, DNS filtrado no sistema inteiro. |

## 2. APIs avaliadas e decisão

### 2.1 UsageStatsManager (estatísticas de uso)

- **O que oferece:** o registro de eventos do sistema (`queryEvents`): atividade retomada, pausada
  e parada, tela interativa e não interativa, teclado de bloqueio exibido e ocultado, desligamento
  e inicialização do aparelho. O registro é mantido pelo sistema por alguns dias e sobrevive a
  reinicializações e à morte do nosso processo.
- **Requisito:** acesso especial "Acesso ao uso" (`PACKAGE_USAGE_STATS`), concedido manualmente
  pelo usuário nas Configurações. Não existe diálogo de permissão em tempo de execução.
- **Limitações:** o usuário pode revogar o acesso a qualquer momento. Eventos usam o relógio de
  parede, então mudanças manuais de data e hora afetam os carimbos. Alguns fabricantes atrasam a
  gravação dos eventos em alguns décimos de segundo.
- **Decisão:** é a **fonte de verdade da contagem de tempo**. O agente processa o fluxo de eventos
  como uma máquina de estados e persiste o ponto até onde já processou. Se o processo morrer, ao
  voltar ele reprocessa os eventos a partir desse ponto e recupera o uso do intervalo em que esteve
  fora. Na ativação, o agente reprocessa o dia corrente desde o horário de reinício da cota, de modo
  que limpar os dados do app e vincular de novo não zera o tempo já usado.

### 2.2 AccessibilityService

- **O que oferece:** aviso imediato de troca de janela (`TYPE_WINDOW_STATE_CHANGED`) com o pacote
  em primeiro plano, a ação global "ir para a tela inicial" e isenção da restrição de abrir
  atividades em segundo plano (necessária para exibir a tela de bloqueio).
- **Requisito:** ativação manual nas Configurações de acessibilidade, com aviso do sistema. Em
  Android 13 ou superior, apps instalados por fora da loja precisam antes liberar as
  "configurações restritas" na tela de informações do app.
- **Limitações:** o usuário pode desativar o serviço. O Google Play exige declaração de uso e
  divulgação destacada.
- **Decisão:** usado **somente** para saber qual pacote está em primeiro plano e para tirar da tela
  um app bloqueado. A configuração do serviço declara apenas `typeWindowStateChanged` e
  `canRetrieveWindowContent="false"`: o serviço é tecnicamente incapaz de ler o conteúdo das
  telas, textos digitados ou senhas. Não há keylogging nem leitura de mensagens.

### 2.3 DevicePolicyManager

**Como administrador ativo (sem ser dono):**
- Impede a desinstalação enquanto o administrador estiver ativo. O usuário pode desativá-lo nas
  Configurações. Antes da desativação o sistema mostra o nosso texto de aviso
  (`onDisableRequested`) e depois chama `onDisabled`, que gera um alerta ao responsável.
- As demais políticas de administrador legado foram descontinuadas pelo Android para apps que não
  são donos do dispositivo e não são usadas.

**Como Device Owner:**
- `setPackagesSuspended`: o sistema impede a abertura do app, oculta suas notificações e mostra um
  diálogo próprio com a nossa mensagem (`setShortSupportMessage`). Persiste após reinicialização e
  independe do nosso processo estar vivo. Alguns pacotes não podem ser suspensos (o próprio dono,
  o launcher ativo, o discador padrão, instalador e verificador de pacotes). O método devolve a
  lista do que não pôde ser suspenso, e para esses casos o agente usa a interceptação.
- `setUninstallBlocked` e `setUserControlDisabledPackages` (API 30+): impedem desinstalar, forçar
  parada e limpar dados do ParentaLynx.
- Restrições de usuário: `DISALLOW_SAFE_BOOT`, `DISALLOW_FACTORY_RESET`, `DISALLOW_ADD_USER`,
  `DISALLOW_CONFIG_DATE_TIME`, `DISALLOW_CONFIG_PRIVATE_DNS`, `DISALLOW_INSTALL_UNKNOWN_SOURCES`,
  `DISALLOW_DEBUGGING_FEATURES` (as três últimas são opcionais, escolhidas pelo responsável).
- `setGlobalPrivateDnsModeSpecifiedHost` (API 29+): DNS privado filtrado no sistema inteiro.
- Isenção das restrições de início de atividade e de serviço em primeiro plano a partir do segundo
  plano, e ausência do app no gerenciador de tarefas de serviços em primeiro plano.
- **Requisito:** o aparelho não pode ter contas nem outros usuários no momento do provisionamento
  (na prática, recém-restaurado). Ver `05-device-owner.md`.
- **Decisão:** é o modo recomendado quando o responsável quer bloqueio robusto. A remoção do modo
  é feita pelo próprio app, mediante autenticação do responsável.

**Configurações gerenciadas (managed configurations):** servem para um app receber parâmetros de um
EMM corporativo de terceiros. Não se aplicam aqui, porque o ParentaLynx é o próprio controlador e
recebe a política do seu backend. Avaliado e descartado.

**Modo de tarefa bloqueada (lock task / quiosque):** avaliado como alternativa para o estado de
"limite atingido". Descartado em favor da suspensão de pacotes, que é mais simples, não corre o
risco de prender o aparelho em uma tela se o app falhar, e mantém a tela inicial normal com as
exceções acessíveis.

### 2.4 Execução persistente

- **Serviço em primeiro plano** (`specialUse`, ou `systemExempted` quando Device Owner): mantém o
  motor de regras vivo com uma notificação permanente, que também serve de aviso de que o controle
  parental está ativo. Em Android 13 ou superior o usuário pode parar apps com serviço em primeiro
  plano pelo gerenciador de tarefas da gaveta de notificações (não se aplica a Device Owner).
- **AccessibilityService:** é vinculado pelo próprio sistema, que o reinicia quando o processo
  morre. Enquanto estiver ativado, traz o motor de volta sozinho.
- **BOOT_COMPLETED e MY_PACKAGE_REPLACED:** religam o serviço após reinicialização e atualização.
  O estado (política, tempo usado, bloqueio manual) fica em disco, então reiniciar não devolve tempo.
- **WorkManager:** sincronização periódica (mínimo de 15 minutos imposto pelo Android) e
  verificação de saúde. Sujeito a Doze e a economia de bateria do fabricante.
- **AlarmManager:** alarme no horário de reinício da cota e no fim de períodos de bloqueio, para
  liberar o aparelho na hora certa mesmo em repouso.
- **Isenção de otimização de bateria:** solicitada na configuração, porque sem ela vários
  fabricantes matam o processo em segundo plano.

### 2.5 Tela de bloqueio

A tela de bloqueio é uma `Activity` nativa em Kotlin, aberta pelo motor quando um app não
autorizado vem para o primeiro plano. Ela não é uma tela Flutter sobreposta. O mecanismo de
bloqueio em si é: suspensão pelo sistema (Device Owner) ou, nos outros modos, a atividade de
bloqueio assumindo o primeiro plano no lugar do app, seguida do encerramento dos processos em
segundo plano do app. Se a atividade não puder ser aberta, o app é mandado para o segundo plano
pela ação global de acessibilidade. A tela explica o motivo, informa o horário de liberação e
oferece pedir mais tempo, ligar para emergência e a área do responsável.

Se a acessibilidade estiver desativada e o app não for Device Owner, a única forma de abrir a tela
de bloqueio a partir do segundo plano é a permissão "Sobrepor a outros apps"
(`SYSTEM_ALERT_WINDOW`), que isenta o app da restrição de início de atividades. Ela é pedida como
camada de reforço.

### 2.6 Rede

- **Navegador gerenciado** (WebView dentro do app): registra URL, domínio, título e horário das
  páginas abertas nele, aplica listas de domínios permitidos e proibidos, categorias e filtro DNS
  familiar consultado por DNS sobre HTTPS antes de cada navegação.
- **DNS privado do sistema:** só pode ser definido por código no modo Device Owner. No modo padrão
  o responsável pode configurá-lo manualmente nas Configurações (o app mostra como), mas a criança
  pode desfazer.
- **VPN local (`VpnService`) só de DNS:** tecnicamente possível no modo padrão. Avaliada e **não
  implementada nesta versão**: exige um interceptador de pacotes próprio, ocupa a única vaga de VPN
  do aparelho, mostra o aviso permanente de VPN e pode ser desligada pelo usuário. Fica registrada
  em `02-arquitetura.md` como evolução.
- **Limite técnico que vale para qualquer abordagem:** não é possível saber com precisão quais
  páginas são abertas em outros aplicativos nem inspecionar conexões HTTPS. Filtro por DNS enxerga
  apenas nomes de domínio e pode ser contornado por apps que usam DNS próprio ou VPN.

### 2.7 Notificações

- Android 13 ou superior exige a permissão `POST_NOTIFICATIONS` em tempo de execução.
- Sem um serviço de push (Firebase Cloud Messaging), um app em segundo plano só consegue buscar
  alertas por tarefas periódicas do WorkManager, com intervalo mínimo de 15 minutos e sujeitas a
  Doze. Com o app aberto, os alertas chegam na hora por WebSocket. A integração com FCM exige um
  projeto Firebase do operador e não faz parte desta entrega. O backend expõe o ponto de extensão.

## 3. Matriz de capacidades

Legenda: **Garantido** (imposto pelo sistema), **Efetivo** (funciona, mas depende de permissão que
o usuário pode desativar), **Detecta** (não impede, mas registra e alerta), **Não** (impossível
nesse modo).

| Capacidade | Padrão | Padrão + Admin | Device Owner |
| --- | --- | --- | --- |
| Medir tempo efetivo de uso por app | Efetivo | Efetivo | Efetivo, com relógio protegido |
| Identificar o app em primeiro plano | Efetivo (imediato com acessibilidade, até 1 s por polling) | Efetivo | Efetivo |
| Bloquear app específico | Efetivo (interceptação, o app pode aparecer por uma fração de segundo) | Efetivo | Garantido (suspensão) |
| Bloqueio geral ao atingir o limite | Efetivo | Efetivo | Garantido para apps suspendíveis |
| Manter exceções disponíveis | Sim | Sim | Sim |
| Chamadas de emergência | Nunca bloqueadas | Nunca bloqueadas | Nunca bloqueadas (o discador não é suspendível) |
| Bloqueio persiste após reiniciar | Efetivo (serviço religa no boot) | Efetivo | Garantido (suspensão fica gravada no sistema) |
| Bloqueio persiste se o processo morrer | Efetivo enquanto a acessibilidade estiver ativa | Efetivo | Garantido |
| Funcionar sem internet | Sim | Sim | Sim |
| Impedir desinstalação | Não, detecta por ausência de sincronização | Parcial: exige desativar o admin, o que gera alerta | Garantido |
| Impedir forçar parada e limpar dados | Não | Não | Garantido (API 30+) |
| Impedir desativar acessibilidade ou acesso ao uso | Detecta | Detecta | Detecta, e o bloqueio por suspensão não depende delas |
| Impedir modo de segurança | Não | Não | Garantido |
| Impedir restauração pelas Configurações | Não | Não | Garantido |
| Impedir restauração pelo modo de recuperação | Não | Não | Não (a proteção contra restauração do Google continua valendo) |
| Impedir alterar data e hora | Detecta e usa hora do servidor | Detecta | Garantido |
| Filtro DNS no sistema inteiro | Não (só no navegador gerenciado) | Não | Garantido (API 29+) |
| Histórico de navegação | Só no navegador gerenciado | Idem | Idem |
| Ler mensagens, teclas ou telas | Não implementado por decisão de projeto | Idem | Idem |

## 4. Formas conhecidas de contorno e resposta do sistema

| Contorno | Modos afetados | Resposta |
| --- | --- | --- |
| Desativar o serviço de acessibilidade | Padrão, Admin | Evento e alerta "permissão alterada". O motor passa a detectar por polling de eventos de uso e bloqueia pela permissão de sobreposição, se concedida. O painel mostra a proteção como degradada. |
| Revogar "Acesso ao uso" | Todos | Evento e alerta. A contagem passa a usar os eventos de acessibilidade (menos precisa). Sem as duas permissões o painel mostra "contagem indisponível". |
| Forçar parada do app | Padrão, Admin | O sistema religa o serviço de acessibilidade em alguns casos, mas um app com parada forçada só volta quando for aberto. O servidor alerta por falta de sincronização. |
| Desinstalar | Padrão (direto), Admin (após desativar) | Alerta de desativação do admin, quando houver, e alerta por falta de sincronização. |
| Modo de segurança | Padrão, Admin | Apps de terceiros não rodam. Detectável apenas por falta de sincronização. |
| Mudar data, hora ou fuso | Padrão, Admin | Evento e alerta. O dia da cota é calculado com a hora do servidor ancorada no relógio monotônico e nunca retrocede. O fuso da cota vem da política, não do aparelho. |
| Limpar os dados do app | Padrão, Admin | O aparelho perde o vínculo e deixa de sincronizar (alerta). Ao vincular de novo, o uso do dia é reconstruído a partir do registro do sistema e o servidor reaproveita o cadastro do mesmo aparelho. |
| Segundo usuário ou perfil | Padrão, Admin | Não coberto. No modo Device Owner a criação de usuários é bloqueada. |
| Tela dividida e janelas flutuantes | Todos | O motor acompanha todas as atividades retomadas e bloqueia se qualquer uma for de app não autorizado. |
| Restauração de fábrica | Todos | Remove tudo. Device Owner bloqueia o caminho pelas Configurações. |

## 5. Restrições de segundo plano por fabricante

Vários fabricantes aplicam regras próprias além do Android padrão: início automático desativado por
padrão (Xiaomi, Redmi e POCO, OPPO, realme, vivo), "apps em suspensão" (Samsung), encerramento ao
bloquear a tela (Huawei). O efeito é o serviço não religar após reinicialização ou morrer com a
tela apagada.

Mitigações implementadas:
1. Pedido de isenção de otimização de bateria na configuração.
2. Três caminhos independentes para religar o motor: serviço de acessibilidade, receptor de boot
   e tarefa periódica.
3. Reprocessamento do registro de eventos do sistema ao voltar, para não perder tempo de uso.
4. A tela de permissões do modo criança mostra instruções específicas quando reconhece o
   fabricante (início automático e bateria sem restrição).
5. O servidor alerta o responsável quando o aparelho fica sem sincronizar.

Limitação assumida: não há API pública para ativar o "início automático" desses fabricantes. É um
passo manual, orientado em tela.

## 6. Versões do Android

- **Mínima:** Android 9 (API 28). É a primeira versão com eventos de tela e de teclado de bloqueio
  no registro de uso.
- **API 29 (Android 10):** restrição de início de atividades em segundo plano, DNS privado por
  política, eventos de desligamento e inicialização.
- **API 30 (Android 11):** visibilidade de pacotes (`QUERY_ALL_PACKAGES`), proteção contra forçar
  parada para Device Owner.
- **API 31 (Android 12):** restrição de início de serviço em primeiro plano a partir do segundo
  plano, alarmes exatos como acesso especial.
- **API 33 (Android 13):** permissão de notificações em tempo de execução, configurações restritas
  para apps instalados por fora da loja, gerenciador de tarefas de serviços em primeiro plano.
- **API 34 (Android 14):** tipo de serviço em primeiro plano obrigatório.
- **API 35 e 36 (Android 15 e 16):** novos limites para serviços `dataSync` (não usados aqui) e
  telas de ponta a ponta.

## 7. Limites de monitoramento assumidos por privacidade

O ParentaLynx **coleta** no aparelho monitorado: lista de apps instalados (nome, pacote, ícone,
categoria), sessões de uso por app (início, fim, duração), tentativas de abrir apps bloqueados,
eventos de bloqueio e liberação, estado das permissões, eventos de segurança (relógio alterado,
reinicialização, proteção desativada), nível de bateria e, somente dentro do navegador gerenciado,
endereços e títulos das páginas.

O ParentaLynx **não coleta e não consegue acessar**: teclas digitadas, senhas, conteúdo de
mensagens, conteúdo de telas, capturas ou gravação de tela, áudio, câmera, fotos, arquivos,
localização, contatos, registro de chamadas, e a navegação feita em outros apps ou navegadores.

A captura de tela foi avaliada e **não foi implementada**: a especificação a trata como opcional e
os relatórios de uso e de navegação cobrem a finalidade parental sem o risco de capturar dados
sensíveis.

O app nunca se oculta: o ícone permanece no launcher, há notificação permanente no modo criança, e
a tela inicial da criança mostra o que é controlado, o que é coletado e quem é o responsável.

## 8. Decisões que seguem desta análise

1. O agente do modo criança é **nativo em Kotlin** e não depende do motor Flutter para contar
   tempo, bloquear ou sincronizar. O Flutter é a interface.
2. Contagem de tempo pelo registro de eventos do sistema, com retomada após falhas.
3. Detecção em camadas: acessibilidade (imediata) e polling de eventos (até 1 s).
4. Bloqueio em camadas: suspensão pelo sistema (Device Owner), ação global de acessibilidade,
   atividade de bloqueio via permissão de sobreposição.
5. A política é avaliada localmente por uma função pura, testável sem aparelho. Funciona offline.
6. O servidor guarda o maior valor de uso já informado para cada dia e o devolve na sincronização,
   de modo que o aparelho nunca "recupera" tempo.
7. Um conjunto fixo de pacotes essenciais nunca é bloqueado: o próprio ParentaLynx, o launcher, a
   interface do sistema, o discador e a pilha de telefonia e de emergência, o controlador de
   permissões e os teclados.
8. O painel do responsável mostra o modo de gerenciamento de cada aparelho e marca como "não
   garantido" tudo o que depende de permissão revogável.

## 9. Validação prática

O que esta análise previa foi conferido em um emulador com Android 16 (API 36, imagem AOSP x86_64).
O roteiro e o resultado de cada item estão em `07-testes.md`. Resumo do que mudou entre a previsão
e a prática:

| Previsto | Observado |
| --- | --- |
| Interceptação com acessibilidade deixa o app aparecer por uma fração de segundo | A tela de bloqueio assume a frente em menos de 0,5 s depois de o app abrir |
| Bloqueio no instante do limite | 4 ms depois do limite pelo relógio do agente (79,4 s medidos de fora para um saldo de 79 s) |
| Sem acessibilidade, o bloqueio cai para polling e sobreposição | Confirmado: o app bloqueado foi coberto pela tela de bloqueio e o responsável recebeu o alerta |
| Uso do período com o processo morto é recuperado do registro do sistema | Confirmado: 36,1 s creditados para 35,5 s de uso, com o processo morto durante 30 s deles |
| O sistema religa o serviço de acessibilidade quando o processo morre | Confirmado: processo de volta em cerca de 2 s |
| Device Owner suspende os apps e impede desinstalar e forçar parada | Confirmado. As Configurações não são suspendíveis e ficam cobertas pela interceptação |
| A ação global "tela inicial" poderia ser usada junto com a tela de bloqueio | Não: ela chega depois e cobre a tela de bloqueio. A ordem foi invertida (seção 2.5) |

Continua sem validação prática: aparelhos físicos, fabricantes com economia de bateria agressiva,
Android 9 a 15, o provisionamento Device Owner por QR code e o comportamento com o aparelho em
repouso prolongado (Doze).
