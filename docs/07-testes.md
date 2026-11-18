# Testes e validação

Este documento separa três coisas: o que é coberto por testes automatizados, o que foi exercitado
de verdade em um emulador Android, e o que ainda não foi validado.

## 1. Resumo

| Camada | Testes | Resultado |
| --- | --- | --- |
| Backend (`backend/test`, `node:test`) | 171 | todos passam |
| Agente nativo Kotlin (`app/android/app/src/test`, JUnit na JVM) | 132 | todos passam |
| Aplicativo Flutter (`app/test`, unidade, widget, arquitetura e Design System) | 878 | todos passam |
| Capturas de tela de referência (temas claro e escuro) | 118 | todas conferem |
| Validação em emulador (Android 16) | roteiro da seção 4 | aprovado antes da migração para BLoC e do Design System, com os defeitos da seção 5 corrigidos; não repetido depois deles |
| Aparelhos físicos | nenhum | não executado |

Verificações estáticas: `flutter analyze` sem apontamentos, `tsc --noEmit` sem erros, compilação
Kotlin sem erros. Builds: APK de depuração e APK de produção gerados.

## 2. Como rodar

```bash
# Backend
cd backend && npm install && npm test && npm run typecheck

# Flutter
cd app && flutter pub get && flutter analyze && flutter test

# Agente nativo (JVM). JAVA_HOME deve apontar para um JDK 17 ou superior.
cd app/android && ./gradlew :app:testDebugUnitTest
```

Capturas de tela de referência das telas principais ficam em pastas `screenshots/` ao lado dos
testes. Para regenerar: `flutter test --update-goldens --tags screenshot`.

### O que cada suíte cobre

- **Backend:** contas e política de senha, bloqueio progressivo, recuperação, elevação,
  vinculação (uso único, validade, aprovação, entrega única das credenciais, vários aparelhos,
  reaproveitamento do cadastro), política versionada e conflito de versão, comandos,
  sincronização (confirmação idempotente, reconciliação pelo maior valor, limites de lote),
  inventário e ícones, pedidos de tempo, alertas e preferências, relatórios, isolamento entre
  contas, cifra em repouso, ausência de segredos no log, revogação, desvinculação local,
  exclusões, retenção, monitor de falta de sincronização, WebSocket e TOTP com os vetores da
  RFC 6238.
- **Agente nativo:** motor de política (toda a precedência, limite exato, tempo extra, suspensão
  por escopo, bloqueio manual, exceções, app novo, limite próprio), calendário da cota e
  horários, rastreador de uso (troca de app, tela apagada, tela dividida, união de sessões,
  viradas de dia e de hora, retomada pelo cursor, reinício), hora confiável, TOTP, leitura da
  política, filtro web, montagem das mensagens de sincronização, validação das entradas que
  chegam pela ponte.
- **Flutter:** organizado por funcionalidade, como o código. Para cada uma: entidades, regras e
  casos de uso (testes puros), mapeadores e repositórios contra o servidor falso, BLoCs com
  `bloc_test` e telas com capturas de referência. Além disso: núcleo (`Result` e falhas, cliente
  da API, canal em tempo real, JSON, senha, TOTP, código de vinculação, formatação), roteamento
  do app montado (perfil, sessão do responsável, vínculo da criança, em `test/app`) e as regras
  de arquitetura (`test/architecture`: camadas, dependências entre funcionalidades sem ciclos,
  contêiner de dependências só na composição), as regras do Design System por funcionalidade
  (`test/architecture/design_system_test.dart`) e o catálogo do Design System
  (`test/shared/design_system`: capturas nos dois temas e perfis, diretrizes de acessibilidade
  do Flutter e fonte 2×). Cada tela principal tem captura nos temas claro e escuro, um teste com
  a fonte no maior tamanho (2×) e a conferência de área de toque, rótulos e contraste
  (`expectAccessible`).

## 3. Ferramentas de ponta a ponta

| Ferramenta | Para que serve |
| --- | --- |
| `backend/scripts/simulate-device.ts` | Simula um aparelho da criança: vincula, envia inventário e uso crescente, reage às regras. Bom para testar o painel sem um segundo aparelho. |
| `scripts/e2e/plx.mjs` | Cliente de linha de comando do responsável: cria conta, gera código, aprova vínculo, altera regras e espera por eventos (`wait-event`, `wait-applied`, `wait-lock`). |
| `scripts/e2e/android.sh` | Funções de `adb`: esperar o boot, tocar em textos da tela, conceder as permissões, ver a atividade em primeiro plano, listar pacotes suspensos. Por segurança, mira só o emulador (`emulator-5554`), a menos que `ANDROID_SERIAL` seja definido. |

Exemplo de sessão com o emulador ligado e o servidor em `localhost:8080`:

```bash
source scripts/e2e/android.sh
P="node scripts/e2e/plx.mjs"
$P register --server http://localhost:8080
$P code                       # digite o código no app, no modo criança
$P approve-next --name João
grant_child_permissions
$P rule com.android.gallery3d blocked && $P wait-applied
launch_pkg com.android.gallery3d; sleep 2; top_activity   # esperado: BlockActivity
$P wait-event blocked_attempt --package com.android.gallery3d
```

## 4. Validação em emulador

Ambiente: emulador oficial do Android, imagem AOSP x86_64 com Android 16 (API 36), em Windows 11.
Servidor local. APK de depuração. Lado do responsável exercitado de duas formas: pela interface do
app (no mesmo emulador, em modo responsável, com o simulador como aparelho da criança) e pela API
com `plx.mjs` (com o emulador como aparelho da criança).

### 4.1 Os quinze itens da especificação

| # | Item | Como foi verificado | Resultado |
| --- | --- | --- | --- |
| 1 | Criação de perfil de responsável | Testes do backend e de widget. No emulador a conta foi criada pela API e usada pela interface (login e desbloqueio) | Aprovado. O formulário de cadastro em si só tem teste de widget |
| 2 | Geração e uso do código de vinculação | Interface do responsável gerou o código e o simulador o usou. Interface da criança usou um código gerado pela API | Aprovado. Número de confirmação igual nos dois lados |
| 3 | Senha administrativa | Testes do backend (Argon2id, política, bloqueio progressivo). No emulador: login, desbloqueio do painel na abertura a frio, senha errada recusada na área do responsável do aparelho da criança | Aprovado |
| 4 | Vários dispositivos | Testes do backend. No emulador a mesma conta teve três aparelhos (dois simulados e o emulador) | Aprovado |
| 5 | Sincronização de configurações | 19 versões de política enviadas ao emulador, cada uma confirmada pelo aparelho em poucos segundos pelo aviso em tempo real. Pela interface: regra salva e a tela mudou de "Aguardando o aparelho confirmar" para "Regras aplicadas no aparelho" | Aprovado |
| 6 | Contagem correta do tempo | Uso real cronometrado de fora. Com o processo do agente morto por 30 s: 36,1 s creditados para 35,5 s de uso. Tempo em exceções e no discador não consumiu cota. O navegador gerenciado foi contado como app próprio | Aprovado |
| 7 | Bloqueio exatamente no limite | Saldo de 79 s: a tela de bloqueio apareceu aos 79,4 s. O agente registrou 240.004 ms usados para o limite de 240.000 ms. Limite próprio de app de 60 s: bloqueio aos 60,4 s | Aprovado |
| 8 | Liberação de exceções | Com o limite esgotado: app marcado como exceção abriu, discador abriu, discador de emergência abriu, app comum e Configurações foram bloqueados | Aprovado |
| 9 | Persistência após reinicialização | Aparelho pausado, emulador reiniciado: serviço e acessibilidade voltaram sozinhos, o app continuou bloqueado e o tempo usado ficou igual (4min01s antes e depois) | Aprovado |
| 10 | Sem internet e sincronização posterior | Wi-Fi e dados desligados: o bloqueio funcionou e o evento não chegou ao servidor. Rede religada: o evento chegou | Aprovado |
| 11 | Bloqueio de apps selecionados | Modo padrão: tela de bloqueio na frente em menos de 0,5 s. Modo Device Owner: pacote suspenso pelo sistema | Aprovado |
| 12 | Recuperação após falhas | `kill -9` no processo: de volta em cerca de 2 s, sem perda de contagem. Atualização do APK: serviço religado. Acessibilidade desligada: bloqueio continuou pela camada de reserva e o responsável foi avisado | Aprovado |
| 13 | Integridade dos relatórios | Testes do backend. No emulador o relatório do dia bateu com o roteiro: 7min58s no total, 7min32s de cota, 11 tentativas bloqueadas, Relógio com exatamente 1min00s (o limite próprio) | Aprovado |
| 14 | Proteção de dados | Testes do backend: isolamento entre contas, cifra de campos em repouso, segredos fora do log, elevação. No emulador: o build de produção recusou endereço sem HTTPS | Aprovado nos testes. Não houve teste de invasão |
| 15 | Cancelamento e revogação | Revogação pelo responsável: controle desativado, apps liberados, modo Device Owner devolvido, app de volta à tela de vinculação. Desvinculação no aparelho com o código offline. Nova vinculação reaproveitou o cadastro, a política e o tempo do dia | Aprovado |

### 4.2 Outros pontos verificados no emulador

- Assistente de permissões: o atalho abriu a tela certa das Configurações e o assistente refletiu
  as permissões concedidas.
- Serviço em primeiro plano ativo com o tipo `specialUse` e notificação permanente.
- Serviço de acessibilidade registrado com `capabilities=0` e só o evento de troca de janela: ele
  não tem como ler o conteúdo das telas.
- Período de bloqueio pontual e suspensão de regras por escopo.
- Modo Device Owner por `adb`: suspensão no bloqueio geral preservando discador e exceções,
  `adb uninstall` recusado, `am force-stop` sem efeito, restrições aplicadas conforme a política
  (depuração USB continuou ligada, como manda o padrão), DNS privado em
  `family.cloudflare-dns.com`.
- Navegador gerenciado: página real carregada, domínio bloqueado mostrado com explicação,
  histórico no servidor com título e motivo.
- Área do responsável no aparelho da criança: código de acesso offline gerado fora do aparelho e
  aceito por ele, liberação local de 15 minutos vencendo um bloqueio manual, evento de segurança
  no servidor.
- Interface do responsável contra o servidor real: painel, salvar limite diário, relatórios,
  alerta em tempo real, aprovação de pedido de tempo, saída da conta.
- APK de produção: abre, lê o modo pela ponte nativa e exige `https://`. Sem erros no log.

## 5. Defeitos encontrados na validação e corrigidos

Nenhum destes aparecia nos testes automatizados. Todos foram achados no emulador.

| Defeito | Correção |
| --- | --- |
| A tela de bloqueio não aparecia: a ação "tela inicial" chegava alguns milissegundos depois e a cobria. O app era fechado, mas sem explicação | A tela de bloqueio abre direto por cima do app. A tela inicial virou o plano de reserva (`BlockController`) |
| O aviso de alerta em tempo real cobria o botão Salvar das regras | O aviso passou a ser uma faixa no topo da tela (`GuardianShell`) |
| Ícone da aba selecionada sem contraste | Cor do indicador ajustada no tema |
| Depois de desvincular no próprio aparelho, o servidor continuava mostrando o aparelho como ativo | O evento `unlinked_locally` revoga o cadastro e entra na auditoria |
| Cinco notificações de "permissão concedida" na configuração inicial | Concessões ficam na central sem notificar. Revogações notificam |
| O cartão de pedidos da criança usava o relógio do aparelho, e não a hora do agente | Corrigido. Era também a causa de uma captura de tela instável |
| O simulador em avanço rápido era recusado pelo servidor (mais de 2 horas de uso em uma hora) | O simulador limita o uso por hora |

## 6. O que não foi validado

- **Interface nova em aparelho real.** O Design System e as telas redesenhadas
  ([avaliação de usabilidade](usabilidade/README.md)) foram verificados por testes de widget,
  capturas de referência, diretrizes de acessibilidade do Flutter e fonte 2×, mas não em
  aparelho: faltam TalkBack, a fonte do sistema no maior tamanho, tamanhos de tela variados, a
  tela de bloqueio nativa redesenhada, o ícone do app e a ida e volta às telas de configuração do
  Android.
- **Roteiro em emulador depois da migração para BLoC.** A interface foi reorganizada com BLoC e
  Clean Architecture ([ADR 0001](adr/0001-bloc-clean-architecture.md)). A migração está coberta
  pelos testes automatizados e o APK de depuração compila, mas o roteiro da seção 4 ainda não foi
  repetido em um emulador nem em aparelho.
- **Aparelhos físicos.** Nada foi testado em hardware real. A especificação pede fabricantes,
  versões e modos de economia de bateria diferentes, e isso não foi feito.
- **Android 9 a 15.** Só o Android 16 foi exercitado. O código trata as diferenças de API, mas
  sem execução.
- **Economia de bateria de fabricante e Doze prolongado.** O comportamento com a tela apagada por
  horas, o início automático e os "apps em suspensão" não foram observados.
- **Provisionamento Device Owner por QR code.** Implementado, sem execução.
- **Build de produção de ponta a ponta.** O APK de produção foi aberto, mas o fluxo completo exige
  um servidor com HTTPS, que não havia no ambiente.
- **Docker.** Os arquivos existem e não foram executados.
- **Alertas em segundo plano no aparelho do responsável.** O worker que busca alertas a cada 15
  minutos compila e está registrado, mas o intervalo não foi esperado no emulador.
- **Telas sem verificação no emulador:** cadastro, recuperação por chave, troca de senha, sessões,
  privacidade, auditoria, detalhe do aparelho, horários permitidos, períodos de bloqueio, apps,
  web e proteção pela interface (as regras correspondentes foram testadas pela API).
- **Pedido de tempo feito no aparelho real.** O fluxo foi exercitado com o simulador e pela
  interface do responsável, não pelo botão da tela de bloqueio.
- **Tema escuro.** Existe e não tem capturas de referência.
- **Desempenho e consumo de bateria.** Não medidos.
- **Segurança.** Não houve teste de invasão nem revisão externa.

## 7. Roteiro para aparelhos físicos

Repetir o roteiro da seção 4 em pelo menos estes cenários, anotando o resultado:

| Cenário | O que observar |
| --- | --- |
| Samsung (One UI), Android 13 ou superior | "Apps em suspensão" e bateria: o controle continua depois de horas com a tela apagada? |
| Xiaomi, Redmi ou POCO | Início automático: o serviço religa depois de reiniciar? A tela de bloqueio aparece (permissão de "exibir janelas em segundo plano")? |
| Motorola ou Pixel (Android próximo do padrão) | Comportamento de referência |
| OPPO, realme ou vivo | Início automático e encerramento em segundo plano |
| Aparelho com Android 9 ou 10 | Contagem de tempo e detecção de reinício sem os eventos de desligamento |
| Instalação por APK no Android 13 ou superior | Liberação das "configurações restritas" para a acessibilidade |
| Modo de economia de bateria ligado | Atraso na sincronização e no bloqueio |
| Tela dividida e janela flutuante | Bloqueio com dois apps visíveis e vídeo em janela flutuante |
| Troca manual de data, hora e fuso | Evento `clock_changed` e dia da cota inalterado |
| Aparelho recém-restaurado | Provisionamento Device Owner por `adb` e por QR code |
| 24 horas de uso normal | Consumo de bateria e precisão do total do dia contra o "Bem-estar digital" do sistema |
| TalkBack ligado, nos dois perfis | Ordem de leitura, nomes dos botões, anúncio dos estados (sincronização, erros, pedido de tempo) |
| Fonte e tela do sistema no maior tamanho | Nenhum texto cortado; o tempo e os códigos continuam legíveis |
| Tema escuro do sistema | Contraste e legibilidade, incluindo a tela de bloqueio nativa |
| Tablet ou celular deitado | Conteúdo centralizado com largura limitada, sem esticar |

Para apontar os roteiros de `scripts/e2e/android.sh` a um aparelho físico:

```bash
export ANDROID_SERIAL=NUMERO_DE_SERIE   # mostrado por `adb devices`
source scripts/e2e/android.sh
```
