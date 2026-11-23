# ADR 0001: Flutter com BLoC, Clean Architecture e organização por funcionalidade

- **Status:** aceito
- **Data:** 17/11/2026
- **Substitui:** a organização com Riverpod descrita nas versões anteriores de `02-arquitetura.md`

## Contexto

A diretriz arquitetural do projeto exige que o aplicativo Flutter use BLoC, Clean Architecture,
SOLID, injeção de dependências, casos de uso, repositórios, DTOs com mapeadores e o padrão
Result, organizado por funcionalidade, com cada camada testável de forma independente.

A versão anterior já separava `domain`, `data` e `presentation`, mas usava controladores do
Riverpod como gerenciador de estado e de dependências, colocava `fromJson`/`toJson` nas
entidades, deixava validações e decisões em widgets e organizava as pastas primeiro por modo
(responsável e criança) e só depois por assunto.

O que não muda: o agente nativo em Kotlin continua sendo quem conta tempo, bloqueia e
sincroniza, com ou sem a interface aberta (seção 2 de `02-arquitetura.md`). O Flutter coordena
e mostra o estado; não é ele que mantém o bloqueio ativo.

## Decisão

### 1. Camadas e regra de dependência

```
lib/
  main.dart        entradas (app principal e navegador gerenciado)
  app/             composição: bootstrap, injeção de dependências, roteador, raízes dos dois
                   motores (app principal e navegador gerenciado)
  core/            infraestrutura sem regra de negócio
  shared/          widgets, tema e serviços de interface usados por várias funcionalidades
  features/<nome>/
    domain/        entidades, enums, contratos de repositório e de serviço, casos de uso
    data/          DTOs, mapeadores, fontes de dados (remote, local, platform), repositórios
    presentation/  BLoCs (bloc/), páginas, widgets, diálogos, textos de tela
    <nome>_module.dart   registro das dependências da funcionalidade
    <nome>_routes.dart   rotas da funcionalidade
```

| Camada | Pode importar | Não pode importar |
| --- | --- | --- |
| `domain` | Dart, `equatable`, `core/{errors,result,time,security,constants,utils,navigation,logging}`, `domain/` de outra funcionalidade | Flutter, BLoC, HTTP, armazenamento, ponte nativa, `core/json`, `data/`, `presentation/` |
| `data` | `domain/` (própria e de outras), `core/` | `presentation/`, `flutter_bloc`, `go_router`, `material_ui`, `get_it` |
| `presentation` | `domain/`, `presentation/` de outra funcionalidade, `shared/`, `core/{bloc,errors,result,time,constants,navigation}` | `data/`, `core/network`, `core/storage`, `core/platform`, `core/json`, `get_it` |
| `core` | só `core` | `features/`, `app/`, `shared/` |
| `shared` | `core` | `features/`, `app/` |
| `features` | — | `app/` |

`get_it` só aparece em `app/` e nos arquivos de raiz das funcionalidades (`_module.dart`,
`_routes.dart`). As dependências entre funcionalidades formam um grafo sem ciclos.

Essas regras são verificadas pelo teste `test/architecture/architecture_test.dart`, que lê os
imports de todo o `lib/` a cada execução da suíte.

### 2. Funcionalidades

| Funcionalidade | Responsabilidade | BLoCs |
| --- | --- | --- |
| `user_role` | Perfil do aparelho (responsável ou criança) | `UserRoleBloc` |
| `onboarding` | Boas-vindas e escolha do perfil | `OnboardingBloc` |
| `authentication` | Conta, sessão, bloqueio do painel, elevação | `AuthBloc`, `LoginBloc`, `RegisterBloc`, `RecoverAccessBloc`, `UnlockBloc`, `ElevationBloc`, `GuardianEntryBloc` |
| `device_sync` | Avisos em tempo real, confirmação da política aplicada, sincronização pedida ao agente | `DeviceSyncBloc` |
| `child_device` | Aparelhos monitorados vistos pelo responsável | `DevicesBloc`, `ChildDeviceBloc`, `OfflineCodeBloc` |
| `device_policy` | Documento de política versionado, salvamento por seção, visão geral das regras | `PolicyOverviewBloc` |
| `screen_time` | Limite diário, tempo extra, pedidos de tempo | `ScreenTimeBloc`, `TimeRequestsBloc` (responsável), `TimeRequestSheetBloc` (criança) |
| `schedules` | Horários permitidos e períodos de bloqueio | `ScheduleBloc` |
| `app_management` | Inventário, regras por app, exceções | `AppManagementBloc`, `AppInventoryBloc` |
| `blocking` | Pausa, suspensão de regras, proteção, filtro de sites | `ProtectionBloc`, `WebFilterBloc` |
| `activity_reports` | Relatórios de uso | `ActivityReportsBloc` e os das telas de detalhe |
| `notifications` | Alertas, preferências, busca de alertas em segundo plano | `NotificationsBloc`, `NotificationPrefsBloc`, `NotificationPermissionBloc` |
| `device_linking` | Vinculação dos dois lados e desvinculação | `DeviceLinkingBloc` (responsável), `ChildLinkBloc` e `ChildLinkingBloc` (criança) |
| `settings` | Conta, sessões, segurança, privacidade, auditoria | um BLoC por tela |
| `guardian` | Casca e painel do responsável (composição) | `GuardianShellBloc`, `GuardianDashboardBloc` |
| `child_mode` | Casca, tela inicial, permissões e área do responsável no aparelho da criança (composição) | `ChildShellBloc`, `ChildDeviceStatusBloc`, `ChildHomeBloc`, `PermissionsBloc`, `GuardianAreaBloc` |
| `managed_browser` | Navegador gerenciado | `BrowserBloc` |

`guardian` e `child_mode` são funcionalidades de composição: montam telas com partes das
outras e por isso ficam no topo do grafo de dependências.

O endereço do servidor não é uma funcionalidade: é fixo no código (`AppConfig.serverUrl`) e
chega às funcionalidades pelo `ServerEndpoint` do núcleo. A antiga `server_config`, que deixava
configurar o endereço no aparelho, foi removida em 23/11/2026.

A diretriz cita `BlockingBloc` e `SettingsBloc` entre os exemplos de divisão. Aqui essas
responsabilidades ficaram em BLoCs menores, um por tela: as restrições são editadas por
`ProtectionBloc`, `WebFilterBloc` e, por app, `AppManagementBloc`; os comandos sobre o aparelho
(bloquear agora, desbloquear, suspender e retomar regras) são casos de uso de `blocking`
(`LockDeviceNow`, `UnlockDevice`, `SuspendRules`, `ResumeRules`) chamados pelas ações rápidas do
`GuardianDashboardBloc`; e cada tela de `settings` tem o seu BLoC (`AccountBloc`,
`SessionsBloc`, `SecuritySettingsBloc`, `AuditLogBloc` e outros).

### 3. BLoC

- Eventos e estados são classes `sealed` com `Equatable`, em arquivos `part` do BLoC
  (`x_bloc.dart`, `x_event.dart`, `x_state.dart`). Estados descrevem situações reais
  (`Loading`, `Loaded`, `Empty`, `Error`, `Connecting`, `Online`, `Offline`...), sem
  combinações de booleanos.
- Andamento de comandos e formulários usa um único valor: `ActionStatus` (`ActionIdle`,
  `ActionRunning`, `ActionSucceeded`, `ActionFailed`) e `FormStatus`. As páginas reagem às
  transições com `BlocListener` para mostrar avisos uma única vez.
- Transformadores de eventos (`core/bloc/event_transformers.dart`): `droppable()` para
  comandos (evita operações duplicadas), `restartable()` para cargas (cancela a anterior),
  `sequential()` quando a ordem importa e `debounceRestartable()` para rajadas (avisos em tempo
  real, busca digitada).
- BLoCs não fazem HTTP, SQL nem leem preferências: chamam casos de uso.
- BLoCs não conversam entre si. Quando um dado é de mais de uma funcionalidade, o repositório
  é a fonte única de verdade e expõe um fluxo (`ObservableValue`); cada BLoC observa o
  repositório (padrão Observer). Exemplos: a sessão (`ISessionRepository`), a conta
  (`ICurrentAccountRepository`), a lista de aparelhos (`IChildDeviceRepository`) e o perfil
  (`IUserRoleRepository`). A única exceção é a página despachar um evento para um BLoC
  fornecido acima dela (escolher o aparelho em foco depois de aprovar um vínculo).
- `AppBlocObserver` registra erros e, em depuração, transições, só com tipos (sem dados
  pessoais).

### 4. Casos de uso, Result e falhas

- Cada operação de negócio é um caso de uso, um por arquivo, com `call`. Regras de
  validação ficam no domínio (entidades com comportamento, como `DailyLimit.withPerWeekday`,
  e serviços puros, como `CredentialsPolicy` e `ChildNamePolicy`).
- Repositórios e casos de uso devolvem `Result<T>` (`Ok`/`Err`). Exceções só existem dentro
  da camada de dados e viram `AppFailure` (`NetworkFailure`, `ApiFailure`, `NativeFailure`,
  `ValidationFailure`, `UnexpectedFailure`, `CancelledFailure`) em `Result.guard` e
  `callNative`.
- Operações administrativas usam `RunElevated`: se o servidor pedir a senha
  (`elevation_required`), o caso de uso pede pela porta `IElevationPrompter` e repete a
  operação uma vez. A porta é implementada na apresentação por um diálogo
  (`DialogElevationPrompter`); o domínio não sabe que existe um diálogo.

### 5. DTOs e mapeadores

A camada de dados tem DTOs que espelham o protocolo (campos opcionais nulos, códigos como
texto) e mapeadores que aplicam os padrões do protocolo e convertem códigos em enums. As
entidades não conhecem JSON. Exemplo: `PolicyDto` + `PolicyMapper`, com teste de ida e volta.

### 6. Strategy e composição nas regras

O documento de política é editado por seção. `PolicySection<T>` é a estratégia de cada seção
(`DailyLimitSection`, `ScheduleSection`, `AppsSection`, `ProtectionSection`, `WebSection`) e
`SavePolicySection` aplica a mesma concorrência otimista a todas: grava sobre a versão em que
a edição começou; se o servidor recusar por versão, só há conflito quando a *mesma seção*
mudou, senão a seção editada é aplicada sobre a versão nova. `PolicySectionEditor<T>` reúne o
ciclo carregar, editar, salvar e acompanhar o servidor, e cada BLoC de regras o usa por
composição, não por herança.

### 7. Injeção de dependências

`get_it` com um módulo por funcionalidade (`register<Funcionalidade>Module(GetIt di)`),
chamados por `app/di/injection.dart`. Ciclos de vida:

| Tipo | Registro | Exemplo |
| --- | --- | --- |
| Infraestrutura, repositórios, serviços | `registerLazySingleton` | `ApiClient`, `GuardianSessionStore` |
| Casos de uso | `registerFactory` | `SignIn`, `SavePolicySection` |
| BLoCs do app inteiro | `registerLazySingleton` com `dispose` | `UserRoleBloc`, `AuthBloc`, `ChildLinkBloc` |
| BLoCs de tela | `registerFactory`, criados pela rota e fechados pelo `BlocProvider` | `LoginBloc`, `ScreenTimeBloc` |
| BLoCs da sessão do painel | `registerFactory`, criados por um `ShellRoute` que envolve o painel aberto | `DevicesBloc`, `DeviceSyncBloc`, `NotificationsBloc` |
| BLoCs da área da criança | `registerFactory`, criados pelo `ShellRoute` da área (`childShellRoute`) | `ChildShellBloc`, `ChildDeviceStatusBloc` |

O escopo da sessão é uma `ShellRoute` em volta das telas do painel: quando o painel bloqueia
ou a sessão termina, o roteador sai dela e esses BLoCs são fechados; ao voltar, são criados de
novo. Nenhuma página acessa o contêiner: os BLoCs chegam pelas rotas.

Serviços de interface (`ShareService`, `Clock`, `AppIconImages`) são entregues pela árvore
de widgets (`RepositoryProvider`).

O navegador gerenciado roda em um motor Flutter próprio (`browserMain`), com a sua raiz de
composição (`configureBrowserDependencies`): só o núcleo e o módulo do navegador. Esse motor
não fala com o servidor, não busca alertas e não trata ações de abertura, que ficam com o motor
do app principal.

O roteador do app escolhe a área pelo perfil e delega a decisão dentro de cada área: a sessão
do responsável (`AuthBloc`) e a fase do vínculo da criança (`childRedirect`, em
`child_mode_routes.dart`, a partir do `ChildLinkBloc`).

### 8. Integração com o Android

O domínio só conhece interfaces; os adaptadores ficam em `data/` e usam o código gerado pelo
Pigeon (`pigeons/native_api.dart`, a única definição da ponte).

| Interface no domínio | Funcionalidade | API nativa |
| --- | --- | --- |
| `IDevicePolicyService` | `device_policy` | `ChildAgentApi.getPolicyJson` |
| `IApplicationMonitor` | `app_management` | `ChildAgentApi` (uso de hoje, apps liberados, ícones, abrir app) |
| `IApplicationBlockingService` | `blocking` | `ChildAgentApi` (liberação local) |
| `IScreenTimeService` | `screen_time` | `ChildAgentApi` (pedidos de tempo) |
| `IBootRecoveryService` | `child_mode` | `ChildAgentApi.ensureRunning` |
| `IPlatformPermissionService` | `child_mode` | `DeviceApi` (permissões e telas do sistema) |
| `IDeviceSyncService` | `device_sync` | `ChildAgentApi.syncNow` |
| `IUserRoleRepository` | `user_role` | `AppModeApi` |
| `IAlertPollingService` | `notifications` | `GuardianNativeApi` |

Erros da ponte chegam como `NativeFailure` com um código padronizado (`NativeErrorCode`):
`admin_auth_required`, `mode_locked`, `forbidden_key`, `policy_invalid`, `invalid_argument`,
`channel-error` e `unknown`. O lado nativo valida as entradas e recusa valores fora do
intervalo com `invalid_argument`.

### 9. Sincronização

| Exigência | Onde está |
| --- | --- |
| Sincronização de políticas | Política versionada; o agente converge para a versão mais recente (`SyncManager`) |
| Envio de eventos de uso | Fila persistente no SQLite do agente (`OutboxStore`), cada item com UUID |
| Recebimento de atualizações | WebSocket do responsável (`device_sync`, `RealtimeUpdate` tipado) e do aparelho (`sync_now`) |
| Confirmação de aplicação | O aparelho confirma `appliedPolicyVersion`; o painel mostra pendente até lá (`PolicySyncStatus`) |
| Recuperação após offline | A fila só sai com o `ack` do servidor; reprocessamento do registro de uso a partir do cursor |
| Duplicidade e idempotência | Itens idempotentes pelo `id`; comandos gravados em `overrides` da política; pedido de tempo repetido em 60 s não gera outro |
| Hora confiável | `TrustedClock` ancorado na hora do servidor e no relógio monotônico |

Isso fica no agente nativo de propósito: precisa funcionar com a interface fechada. No
Flutter, o responsável salva regras com concorrência otimista por seção e o painel nunca trata
uma política como aplicada só porque o servidor aceitou.

### 10. Dependências avaliadas

| Biblioteca | Decisão | Motivo |
| --- | --- | --- |
| `flutter_bloc`, `bloc` | Adotada | Gerenciador de estado exigido |
| `bloc_concurrency` | Adotada | Transformadores `droppable`, `restartable`, `sequential` |
| `stream_transform` | Adotada | `debounce` do transformador de rajadas (já era dependência transitiva) |
| `equatable` | Adotada | Igualdade por valor de eventos, estados e entidades, sem geração de código |
| `get_it` | Adotada | Contêiner de dependências |
| `bloc_test`, `mocktail` | Adotadas (testes) | Testes de BLoC e dublês |
| `freezed`, `json_serializable` | Não adotadas | `sealed` + `Equatable` atendem a imutabilidade, e o leitor tipado `JsonMap` valida o JSON na fronteira; evitam geração de código a cada mudança |
| `injectable` | Não adotada | Os módulos explícitos mantêm o domínio sem anotações de framework e deixam os ciclos de vida visíveis |
| `dio`, `retrofit` | Não adotadas | O `ApiClient` sobre `http` já converte todo erro em `AppFailure` e é testado; trocar não traria ganho |
| `drift` | Não adotada | O Flutter não guarda dados relacionais; o banco do controle é o SQLite do agente nativo |
| `flutter_secure_storage` | Não adotada | O armazenamento seguro é o Keystore nativo, compartilhado com o worker Kotlin de alertas |

## Consequências

- Cada camada é testada sozinha: casos de uso e mapeadores com testes puros, repositórios
  contra um servidor falso, BLoCs com `bloc_test`, telas com capturas de referência e a
  arquitetura com `architecture_test.dart`.
- Mais arquivos por funcionalidade. Em troca, cada um tem uma responsabilidade e as regras
  ficam fora dos widgets.
- O rascunho de regras passou a ser por tela (antes era compartilhado pela aba), e conflitos
  de versão só aparecem quando a mesma seção mudou em outra sessão.
- No modo criança, uma só consulta ao agente por segundo, feita pela casca da área e só com o
  aparelho vinculado e o app em primeiro plano, substitui as consultas de cada tela. A área do
  responsável no aparelho reconhece o acesso vencido pelo próprio erro da ponte
  (`admin_auth_required`), sem uma chamada extra para conferir.
- Testes de widget: fechar um BLoC que ainda escuta fluxos não termina sob o relógio simulado
  (`testWidgets`), porque o `cancel()` das assinaturas devolve um futuro da zona raiz. Por isso
  `TestDependencies.dispose()` não espera o descarte; os BLoCs das telas são fechados pelos
  `BlocProvider`.
