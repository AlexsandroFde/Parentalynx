# Arquitetura

Leia antes `01-capacidades-android.md` (o que o Android permite) e `03-protocolo.md` (contrato
entre os componentes).

## 1. Visão geral

```
  Aparelho do responsável                Servidor                    Aparelho da criança
 ┌────────────────────────┐      ┌────────────────────┐      ┌──────────────────────────────┐
 │ Flutter (modo           │ HTTPS│ Node 24 + Fastify   │ HTTPS│ Agente nativo Kotlin          │
 │ responsável)            │◄────►│ SQLite (node:sqlite)│◄────►│  contagem, bloqueio, sync     │
 │  painel, regras,        │  WS  │ WebSocket           │  WS  │ Flutter (modo criança)        │
 │  relatórios, alertas    │      │ auditoria, alertas  │      │  vínculo, permissões, status  │
 │ Kotlin: alertas em      │      │ retenção            │      │  navegador gerenciado         │
 │ segundo plano           │      └────────────────────┘      └──────────────────────────────┘
 └────────────────────────┘
```

Um único aplicativo Android (`com.parentalynx.app`) contém os dois modos. A escolha é feita na
primeira abertura e fica gravada no lado nativo.

Três bases de código:

| Pasta | Linguagem | Papel |
| --- | --- | --- |
| `app/lib` | Dart (Flutter) | Toda a interface e a lógica compartilhável |
| `app/android` | Kotlin | Agente do modo criança, ponte com o sistema, alertas em segundo plano |
| `backend` | TypeScript (Node 24) | Contas, vínculo, política, sincronização, relatórios, alertas |

## 2. Decisões principais

1. **Agente nativo independente do Flutter.** Contar tempo, bloquear e sincronizar precisam
   funcionar com a interface fechada, depois de reiniciar e com pouca memória. Um motor Flutter em
   segundo plano custaria memória e seria o primeiro a ser morto por fabricantes agressivos. Por
   isso o agente é Kotlin puro e o Flutter só consulta o estado pela ponte.
2. **Ponte tipada com Pigeon.** `app/pigeons/native_api.dart` é a única definição. Não há
   `MethodChannel` manual nem mapas sem tipo.
3. **Política como documento versionado.** O responsável edita um documento JSON. O servidor
   incrementa a versão a cada mudança. O aparelho converge para a versão mais recente e confirma a
   versão aplicada. Comandos (tempo extra, bloquear agora, suspender regras) são parte do mesmo
   documento, em `overrides`, então são idempotentes e sobrevivem a perda de conexão.
4. **Avaliação local e pura.** A decisão de bloquear é uma função sem efeitos colaterais (política
   + uso + instante), em Kotlin, testada na JVM. O aparelho não depende de rede para aplicar regras.
5. **Registro de uso do sistema como fonte de verdade**, com retomada (ver 4.2).
6. **Backend próprio, sem serviços de terceiros.** Node 24 executa TypeScript direto, traz SQLite
   e Argon2 embutidos. Um único processo e um arquivo de banco: simples de hospedar. O acesso a
   dados fica isolado em repositórios, para permitir a troca por PostgreSQL.
7. **Sem push de terceiros nesta versão.** Alertas em tempo real por WebSocket com o app aberto e
   busca periódica em segundo plano (15 minutos). FCM fica como ponto de extensão documentado.
8. **Privacidade por construção.** O serviço de acessibilidade não pode ler conteúdo de tela. Não
   há captura de tela, keylogging nem leitura de mensagens. O histórico de navegação existe só no
   navegador gerenciado.

## 3. Aplicação Flutter (`app/lib`)

BLoC, Clean Architecture e organização por funcionalidade. As decisões, as regras de
dependência e as bibliotecas avaliadas estão em
[`adr/0001-bloc-clean-architecture.md`](adr/0001-bloc-clean-architecture.md).

```
lib/
  main.dart                 entradas: main() e browserMain()
  app/                      composição: bootstrap, injeção de dependências, roteador e as
                            raízes do app principal e do navegador gerenciado
  core/                     infraestrutura sem regra de negócio
    bloc/                   transformadores de eventos, andamento de comandos, observador
    constants/              caminhos de navegação, chaves de armazenamento, nome do app
    errors/                 falhas tipadas (AppFailure)
    result/                 Result (Ok/Err)
    json/                   leitura tipada de JSON (só a camada de dados usa)
    logging/                registro estruturado
    navigation/             ações de abertura vindas do lado nativo
    network/                cliente da API, WebSocket, endereço do servidor (fixo), credenciais
    platform/               código gerado pelo Pigeon e adaptadores da ponte
    security/               política de senha, TOTP, código de vinculação
    storage/                armazenamento seguro e preferências locais
    time/ utils/            relógio, formatação, valor observável
  shared/                   Design System (tokens, temas, componentes) e serviços de interface
  features/
    user_role/  onboarding/  authentication/  device_sync/
    child_device/  device_policy/  screen_time/  schedules/  app_management/
    blocking/  activity_reports/  notifications/  device_linking/  settings/
    guardian/  child_mode/  managed_browser/
```

Cada funcionalidade tem `domain/` (entidades, contratos, casos de uso; Dart puro),
`data/` (DTOs, mapeadores, fontes de dados, repositórios), `presentation/` (BLoCs, páginas,
widgets) e, na raiz, o módulo de dependências e as rotas. As regras de dependência entre
camadas e entre funcionalidades são conferidas por `test/architecture/architecture_test.dart`.

Regras de código:

- Estado com BLoC: eventos e estados `sealed` e imutáveis; BLoCs chamam casos de uso e não
  conversam entre si. Dados de mais de uma funcionalidade têm um repositório como fonte única
  de verdade, observado pelos BLoCs.
- Injeção de dependências com `get_it`, um módulo por funcionalidade. Só a composição acessa
  o contêiner; as páginas recebem os BLoCs pelas rotas.
- Sem `dynamic`. `Object?` aparece só na fronteira de decodificação de JSON, dentro de
  `core/json`, e é convertido de imediato para DTOs tipados.
- Repositórios e casos de uso devolvem `Result`; erros de rede, da API e da ponte viram
  `AppFailure` antes de sair da camada de dados.
- Textos em português do Brasil. A internacionalização por ARB fica como evolução (o app já
  usa `flutter_localizations` para os componentes do Material).

## 4. Agente nativo (`app/android`, pacote `com.parentalynx.app`)

```
bridge/        código gerado pelo Pigeon e as implementações das APIs
core/          SecureStore (Keystore), TrustedClock, Totp, utilitários JSON
policy/        modelo da política, PolicyEngine (puro), calendário da cota e horários
usage/         UsageTracker (puro), fonte de eventos do sistema, fonte por acessibilidade
data/          AgentDatabase (SQLite), repositórios de uso, fila de saída, política
apps/          inventário de apps, pacotes essenciais, categorias, ícones
enforcement/   EnforcementEngine, BlockController, BlockActivity, DeviceOwnerController
service/       EnforcementService, ParentalAccessibilityService, receptores, workers
sync/          ApiClient (OkHttp), SyncManager, RealtimeClient
web/           WebFilter, categorias de domínio, resolvedor DNS sobre HTTPS
permissions/   verificação de permissões especiais e atalhos de configuração
```

### 4.1 Classificação de pacotes

Cada pacote em primeiro plano recebe três propriedades:

| Propriedade | Significado |
| --- | --- |
| `essential` | Nunca é bloqueado e nunca consome cota. |
| `tracked` | O tempo aparece nos relatórios (`totalUsedMs`, sessões, uso por app). |
| consome cota | Regra `allowed`, ou `exception` com `countsTowardLimit`, sem suspensão do limite. |

**Essenciais:**
- o próprio ParentaLynx, exceto a atividade do navegador gerenciado, que é tratada como o pacote
  virtual `com.parentalynx.app.browser`;
- o launcher padrão e os launchers de sistema;
- interface do sistema: `android`, `com.android.systemui`, `com.android.intentresolver`;
- telefonia e emergência: o discador padrão e o de sistema (`TelecomManager`),
  `com.android.phone`, `com.android.server.telecom`, `com.android.incallui`,
  `com.android.emergency`, apps de segurança pessoal conhecidos e os receptores de alertas de
  emergência (`cellbroadcastreceiver`);
- controlador de permissões e instalador de pacotes;
- teclados habilitados;
- qualquer pacote de sistema **sem ícone no launcher** (seletor de arquivos, login de conta,
  compartilhamento). Sem isso, apps liberados como exceção quebrariam ao abrir essas telas.

**Rastreados:** pacotes com ícone no launcher ou instalados pelo usuário, exceto launchers e a
interface do próprio ParentaLynx. O discador é essencial e rastreado: nunca é bloqueado, não
consome cota, mas o tempo aparece nos relatórios.

As Configurações do Android são um app comum: seguem as regras gerais e podem ser bloqueadas.

### 4.2 Contagem de tempo (`UsageTracker`)

Máquina de estados pura alimentada por eventos ordenados no tempo:

- `ACTIVITY_RESUMED(pacote, classe)`: entra no conjunto de atividades retomadas.
- `ACTIVITY_PAUSED` e `ACTIVITY_STOPPED`: sai do conjunto.
- `SCREEN_NON_INTERACTIVE` e `DEVICE_SHUTDOWN`: fecha tudo e esvazia o conjunto.
- `SCREEN_INTERACTIVE`: volta a contar.

O tempo entre dois eventos consecutivos é creditado aos pacotes retomados naquele intervalo, se a
tela estava interativa. O crédito é dividido nas viradas de dia da cota e de hora. Sessões do
mesmo pacote separadas por menos de 1,5 s são unidas (troca de telas dentro do app). Uma abertura
é contada quando o pacote volta ao primeiro plano depois de pelo menos 2 s fora.

Retomada após falhas:

- O estado do rastreador e o cursor (carimbo do último evento e quantos eventos daquele carimbo já
  foram processados) ficam em disco.
- Um batimento com a hora atual é gravado a cada 10 s.
- Ao iniciar, o motor compara a identidade do boot. Se o aparelho reiniciou, fecha as sessões no
  último batimento e esvazia o conjunto. Depois consulta os eventos a partir do cursor e os
  reprocessa. O uso do período em que o processo esteve morto é recuperado do registro do sistema.
- Na ativação, reprocessa desde o início do dia da cota corrente.
- Sem "Acesso ao uso", a fonte passa a ser o serviço de acessibilidade, que sintetiza os mesmos
  eventos a partir das trocas de janela (menos preciso, sinalizado em `issues`).

### 4.3 Motor (`EnforcementEngine`)

Um único laço em uma thread própria, acionado por: temporizador de 1 s enquanto a tela está
ligada, evento do serviço de acessibilidade, alarme de fronteira (reinício da cota, início ou fim
de período, fim de suspensão), chegada de política nova e broadcasts de tela, hora e pacotes.

A cada passo:

1. Lê a hora confiável e vira o dia da cota se preciso.
2. Busca os eventos novos e alimenta o rastreador.
3. Para cada pacote em primeiro plano, avalia a política. Se bloqueado, aciona o bloqueio.
4. Recalcula o bloqueio geral do aparelho. Na mudança, registra `lock_started`, `lock_ended` e
   `limit_reached`, atualiza o conjunto de pacotes suspensos (Device Owner) e a notificação.
5. Emite avisos de pouco tempo (`warnAtMinutes` para a criança, `low_time` para o responsável).
6. Verifica as permissões a cada 15 s e registra mudanças.
7. Agenda o próximo passo para o menor entre 1 s e o tempo até a próxima fronteira. Com a tela
   apagada o laço para, e o alarme de fronteira o acorda.

O bloqueio no instante exato do limite vem do item 7: o passo seguinte é agendado para o momento
em que o saldo chega a zero.

### 4.4 Bloqueio (`BlockController`)

Em ordem, usando o que estiver disponível:

1. **Device Owner:** o pacote já está suspenso pelo sistema e não chega a abrir. O conjunto
   suspenso é recalculado a cada mudança de estado: apps `blocked`, apps com limite próprio
   atingido e, durante um bloqueio geral, todos os apps com ícone que não são essenciais nem
   exceção. Pacotes que o sistema se recusa a suspender caem nos itens seguintes.
2. **Tela de bloqueio por cima do app:** abre a `BlockActivity` direto sobre o app não autorizado.
   O Android só permite abrir uma atividade a partir do segundo plano com o serviço de
   acessibilidade vinculado, com a permissão de sobreposição ou como dono do dispositivo.
3. **Reserva:** se depois de 600 ms a tela de bloqueio não estiver na frente, o app é tirado da
   tela pela ação global "tela inicial" da acessibilidade (ou abrindo a tela inicial) e a tela de
   bloqueio é tentada de novo.
4. Em todos os casos, encerra os processos em segundo plano do app bloqueado.

A ordem importa. Pedir a tela inicial e a tela de bloqueio ao mesmo tempo não funciona: a ação
global é assíncrona, chega alguns milissegundos depois e cobre a tela de bloqueio. Isso foi visto
no teste em emulador e corrigido. A tela de bloqueio é aberta com `FLAG_ACTIVITY_NO_USER_ACTION`,
para o app coberto não entrar em janela flutuante e continuar tocando.

A `BlockActivity` é nativa. Mostra o motivo, o horário de liberação, os apps liberados, e os
botões de pedir mais tempo, emergência e área do responsável.

### 4.5 Hora confiável (`TrustedClock`)

- A cada sincronização guarda o par (hora do servidor, relógio monotônico).
- `now()` = hora do servidor + tempo monotônico decorrido, enquanto o boot for o mesmo.
- Depois de reiniciar sem rede, usa o relógio do aparelho, mas nunca retrocede abaixo da maior
  hora confiável já gravada. Nesse estado `clockTrusted` é falso.
- Mudanças manuais de hora e de fuso geram `clock_changed`.
- O dia da cota usa o fuso da política, não o do aparelho.

### 4.6 Sincronização (`SyncManager`)

- Dispara: na ativação, em eventos relevantes (com espera de 5 s para agrupar), ao receber
  `sync_now`, ao recuperar a rede, ao abrir o app, a cada 2 minutos com a tela ligada e a cada 15
  minutos pelo WorkManager.
- Sessões, eventos e navegação ficam em uma fila local e só saem dela com o `ack` do servidor.
- O WebSocket fica aberto enquanto a tela está ligada, com reconexão progressiva.
- `device_revoked` desativa o controle: remove suspensões e restrições, apaga as credenciais e
  mostra o aviso de vínculo removido.

### 4.7 Armazenamento local

- **SecureStore:** valores cifrados com AES-256-GCM e chave não exportável do Android Keystore.
  Guarda token do aparelho, segredo offline, token de sessão do responsável.
- **AgentDatabase (SQLite, área privada do app):** uso por dia e por app, filas de saída, pedidos
  de tempo, estado do rastreador, política. Protegido pela criptografia de arquivos do Android.
- Backup do sistema desligado (`allowBackup="false"` e regras de extração vazias).

## 5. Backend (`backend/src`)

```
server.ts          entrada: lê configuração, sobe o servidor, liga as tarefas periódicas
app.ts             monta o Fastify (usado também pelos testes)
config.ts          variáveis de ambiente
db/                conexão, migrações SQL numeradas
core/              erros, tokens, cifra de campos, senhas, limite de taxa, tempo e fuso, TOTP
modules/
  auth/            registro, login, recuperação, sessões, elevação
  guardian/        perfil, preferências, auditoria, exclusão da conta
  pairing/         códigos, pedido de vínculo, aprovação
  devices/         aparelhos, política, comandos, inventário para o painel
  policy/          esquema, validação, política padrão, resumo de diferenças
  sync/            sincronização do aparelho, inventário, ícones, verificação de senha
  reports/         agregações
  alerts/          geração a partir de eventos, preferências, monitor de falta de sincronização
  realtime/        WebSocket
  retention/       limpeza
```

Segurança: tokens opacos de 256 bits guardados só como hash, Argon2id para senhas, elevação para
operações administrativas, limite de taxa, auditoria, verificação de posse em toda rota (um
responsável só enxerga os aparelhos da própria conta), cifra de campos sensíveis em repouso,
cabeçalhos de segurança e limite de tamanho de corpo. HTTPS é terminado por um proxy reverso
(Caddy no `docker-compose.yml`), e o app Android em build de produção recusa tráfego sem TLS.

Escala: um processo e um arquivo SQLite em modo WAL. O hub de WebSocket é em memória, então não
há suporte a múltiplas instâncias. Suficiente para uso familiar e pequenas operações. O caminho de
crescimento é trocar os repositórios por PostgreSQL e o hub por um barramento.

## 6. Evoluções registradas (fora desta entrega)

- Push por FCM para alertas imediatos com o app do responsável fechado.
- Filtro DNS por VPN local no modo padrão.
- Desbloqueio do app do responsável por biometria.
- Internacionalização por arquivos ARB.
- iOS (exigiria as APIs Family Controls e Screen Time, com outra arquitetura de agente).
