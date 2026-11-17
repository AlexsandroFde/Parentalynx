# Protocolo: API, política, eventos e sincronização

Este é o contrato entre os três componentes: backend (Node), agente nativo do modo criança
(Kotlin) e aplicação Flutter (Dart). Qualquer mudança aqui precisa ser refletida nos três.

## 1. Convenções

- Prefixo `/v1`. Corpo JSON em UTF-8. Nomes de campos em `camelCase`.
- Instantes: milissegundos desde a época Unix, em UTC (`number`). Sufixo `At` ou `Ms`.
- Dia da cota: texto `YYYY-MM-DD` no fuso da política (ver 3.2).
- Durações: milissegundos, salvo quando o nome termina em `Minutes`.
- Identificadores: UUID v4 em texto.
- Autenticação: cabeçalho `Authorization: Bearer <token>`. Há três tipos de token, reconhecíveis
  pelo prefixo: sessão do responsável `gs_`, aparelho `dv_`, consulta de vinculação `pp_`.
  O servidor guarda apenas o SHA-256 de cada token.
- Dias da semana: ISO, `1` = segunda-feira, `7` = domingo.
- Horários locais: texto `HH:mm` de `00:00` a `23:59`. Em `end` aceita-se também `24:00`.

### 1.1 Erros

Resposta de erro: status HTTP adequado e corpo

```json
{ "error": { "code": "elevation_required", "message": "Confirme a senha administrativa.", "details": {} } }
```

| `code` | HTTP | Significado |
| --- | --- | --- |
| `validation_error` | 400 | Corpo ou parâmetros inválidos. `details.fields` lista os campos. |
| `weak_password` | 400 | Senha fora da política (1.2). `details.reasons` lista os motivos. |
| `invalid_credentials` | 401 | E-mail, senha, chave de recuperação ou código errado. |
| `unauthorized` | 401 | Token ausente ou desconhecido. |
| `session_expired` | 401 | Sessão do responsável expirada ou revogada. |
| `device_revoked` | 401 | Token de aparelho revogado. O agente deve desativar o controle. |
| `elevation_required` | 403 | A operação exige senha confirmada recentemente (2.2). |
| `forbidden` | 403 | Recurso de outra conta. |
| `not_found` | 404 | Recurso inexistente. |
| `email_in_use` | 409 | Já existe conta com o e-mail. |
| `version_conflict` | 409 | `baseVersion` não é a versão atual da política. `details.currentVersion`. |
| `conflict` | 409 | Estado incompatível (por exemplo aprovar vínculo já resolvido). |
| `code_expired` | 410 | Código de vinculação vencido ou já usado. |
| `payload_too_large` | 413 | Lote acima do limite. |
| `account_locked` | 423 | Bloqueio temporário por tentativas. `details.retryAfterSec`. |
| `rate_limited` | 429 | Muitas requisições. `details.retryAfterSec`. |
| `internal` | 500 | Erro inesperado. |

### 1.2 Política de senha administrativa

De 10 a 128 caracteres, com pelo menos 3 das 4 classes (minúscula, maiúscula, dígito, símbolo),
sem conter o trecho local do e-mail nem o nome de exibição (comparação sem distinção de caixa, a
partir de 4 caracteres), e fora da lista embutida de senhas comuns. O servidor é a autoridade. O
app repete a validação para dar retorno imediato. Motivos possíveis em `details.reasons`:
`too_short`, `too_long`, `few_classes`, `contains_identity`, `common`.

Armazenamento: Argon2id (memória 19456 KiB, 2 passagens, paralelismo 1, sal de 16 bytes, saída de
32 bytes), no formato de texto PHC. A senha nunca é gravada nem registrada em log.

## 2. Contas, sessões e segurança administrativa

### 2.1 Objetos

**Guardian**
```json
{
  "id": "uuid", "email": "maria@exemplo.com", "displayName": "Maria", "createdAt": 0,
  "settings": { "retentionDays": 90, "syncStaleMinutes": 180, "offlineHours": 24, "lowTimeMinutes": 10 },
  "notificationPrefs": { "limit_reached": true, "low_time": true, "blocked_app_attempt": true,
    "sync_stale": true, "device_offline": true, "policy_changed": true, "enforcement_failure": true,
    "time_request": true, "permission_changed": true, "new_app_installed": true,
    "security_event": true, "device_linked": true }
}
```
Limites de `settings`: `retentionDays` 30 a 365, `syncStaleMinutes` 30 a 1440, `offlineHours` 6 a
168, `lowTimeMinutes` 1 a 60.

**Session** (na criação inclui `token`)
```json
{ "id": "uuid", "deviceName": "Galaxy da Maria", "createdAt": 0, "lastSeenAt": 0,
  "expiresAt": 0, "elevatedUntil": 0, "current": true }
```

### 2.2 Elevação

A sessão tem `elevatedUntil`. Registro, login e recuperação já deixam a sessão elevada por 15
minutos. Depois disso, as rotas marcadas com **(E)** respondem `elevation_required` até o app
chamar `POST /v1/guardian/session/elevate` com a senha. O app trata esse erro pedindo a senha e
repetindo a operação.

### 2.3 Proteção contra tentativas

- Login, elevação e troca de senha: contador por conta. A partir de 5 falhas seguidas a conta fica
  bloqueada por 1 minuto, dobrando a cada nova falha até 60 minutos. Sucesso zera o contador.
- Recuperação: contador próprio por conta, 5 falhas bloqueiam por 60 minutos.
- Verificação de senha no aparelho da criança: contador por aparelho (não afeta a conta), 5 falhas
  bloqueiam por 5 minutos, dobrando até 60, e geram alerta `security_event`.
- Limite por IP em todas as rotas públicas (janela fixa em memória).

### 2.4 Rotas públicas

| Método e rota | Corpo | Resposta |
| --- | --- | --- |
| `GET /health` | | `{ "status": "ok", "time": 0 }` |
| `GET /v1/meta` | | `{ "serverTime": 0, "apiVersion": 1, "name": "ParentaLynx" }` |
| `POST /v1/auth/register` | `{ email, displayName, password, deviceName }` | 201 `{ guardian, session, recoveryKey }` |
| `POST /v1/auth/login` | `{ email, password, deviceName }` | `{ guardian, session }` |
| `POST /v1/auth/recover` | `{ email, recoveryKey, newPassword, deviceName }` | `{ guardian, session, recoveryKey }` |

`recoveryKey` tem o formato `RK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` (25 caracteres do alfabeto de 2.6,
125 bits). É mostrada uma única vez. O servidor guarda só o hash. A recuperação troca a senha, gera
nova chave, revoga todas as outras sessões e registra auditoria.

### 2.5 Rotas do responsável (token `gs_`)

| Método e rota | Corpo | Resposta |
| --- | --- | --- |
| `POST /v1/auth/logout` | | 204 |
| `GET /v1/guardian/me` | | `{ guardian, session }` |
| `PATCH /v1/guardian/me` **(E)** | `{ displayName?, settings? }` | `{ guardian }` |
| `POST /v1/guardian/session/elevate` | `{ password }` | `{ elevatedUntil }` |
| `POST /v1/guardian/password` | `{ currentPassword, newPassword }` | 204, revoga as outras sessões |
| `POST /v1/guardian/recovery-key` | `{ password }` | `{ recoveryKey }` |
| `GET /v1/guardian/sessions` | | `{ sessions: [Session] }` |
| `DELETE /v1/guardian/sessions/:id` **(E)** | | 204 |
| `PUT /v1/guardian/notification-prefs` | `{ <tipo>: boolean, ... }` | `{ notificationPrefs }` |
| `DELETE /v1/guardian/account` | `{ password }` | 204, apaga a conta e todos os dados |
| `GET /v1/guardian/audit?before=&limit=` | | `{ entries: [AuditEntry], nextBefore }` |
| `GET /v1/guardian/alerts?after=&before=&limit=&notifyOnly=` | | `{ alerts: [Alert], latestId, unread }` |
| `POST /v1/guardian/alerts/read` | `{ ids?: [number], all?: boolean }` | `{ unread }` |
| `GET /v1/guardian/stream` (WebSocket) | | ver seção 7 |

**AuditEntry**: `{ "id": 0, "at": 0, "action": "policy.update", "sessionId": "uuid|null",
"deviceName": "Galaxy da Maria", "targetType": "device|guardian|session|pairing", "targetId":
"uuid|null", "summary": "Limite diário alterado de 2h para 2h30", "ip": "1.2.3.4" }`

**Alert**: `{ "id": 0, "type": "limit_reached", "deviceId": "uuid|null", "childName": "João|null",
"createdAt": 0, "readAt": null, "notify": true, "title": "Limite diário atingido", "body": "João
usou as 2h30 de hoje.", "data": {} }`. `title` e `body` vêm prontos do servidor em português.
`notify` é falso quando o tipo está desligado nas preferências: o alerta continua na central, mas
não gera notificação.

## 3. Vinculação

### 3.1 Fluxo

1. Responsável: `POST /v1/guardian/pairing-codes` **(E)** gera o código (validade de 15 minutos,
   uso único). Só existe um código ativo por conta. Gerar outro invalida o anterior.
2. Criança: `POST /v1/pairing/claim` com o código e os dados do aparelho. O código é consumido, um
   vínculo `pending` é criado e a resposta traz `pollToken` e `confirmCode` (4 dígitos).
3. Responsável: recebe `link_pending` pelo WebSocket (ou consultando a lista), confere o
   `confirmCode` mostrado nos dois aparelhos e chama `approve` ou `reject`.
4. Criança: consulta `GET /v1/pairing/status` até sair de `pending`. Em `approved` recebe as
   credenciais **uma única vez**. O `pollToken` deixa de valer depois da entrega.
5. Um vínculo pendente expira 30 minutos após o `claim`.

Se o `hardwareId` informado já pertence a um aparelho da mesma conta (ativo ou revogado), a
aprovação **reaproveita** esse cadastro: política e histórico são mantidos e o token é trocado. O
vínculo pendente traz `relink: true` para o responsável saber.

### 3.2 Rotas

| Método e rota | Corpo | Resposta |
| --- | --- | --- |
| `POST /v1/guardian/pairing-codes` **(E)** | | 201 `{ id, code, expiresAt }` |
| `GET /v1/guardian/pairing-codes/active` | | `{ code: { id, expiresAt } \| null, pending: [Device] }` |
| `DELETE /v1/guardian/pairing-codes/:id` | | 204 |
| `POST /v1/pairing/claim` (pública) | `{ code, device: DeviceInfo }` | 201 `{ linkId, pollToken, confirmCode, guardianName, expiresAt }` |
| `GET /v1/pairing/status` (token `pp_`) | | `PairingStatus` |
| `POST /v1/guardian/devices/:id/approve` **(E)** | `{ childName }` | `{ device }` |
| `POST /v1/guardian/devices/:id/reject` | | 204 |

**DeviceInfo**: `{ "name": "Moto G de João", "model": "moto g54", "manufacturer": "motorola",
"androidRelease": "14", "sdkInt": 34, "appVersion": "1.0.0", "timezone": "America/Fortaleza",
"hardwareId": "hex sha-256" }`

**PairingStatus**
```json
{ "status": "pending | approved | rejected | expired",
  "credentials": { "deviceId": "uuid", "deviceToken": "dv_...", "offlineSecret": "BASE32" },
  "childName": "João", "guardianName": "Maria",
  "policyVersion": 1, "policy": { } }
```
`credentials`, `childName`, `policyVersion` e `policy` só aparecem em `approved`.

### 3.3 Código de vinculação

8 caracteres do alfabeto `0123456789ABCDEFGHJKMNPQRSTVWXYZ` (sem I, L, O, U), exibidos como
`XXXX-XXXX`. Normalização na entrada: maiúsculas, remover espaços e hífens, `O` vira `0`, `I` e
`L` viram `1`. O servidor guarda o SHA-256 do código normalizado.

### 3.4 Código de acesso offline do responsável

Serve para o responsável se autenticar no aparelho da criança sem internet. É um TOTP (RFC 6238)
com HMAC-SHA256, 8 dígitos, passo de 60 segundos, aceitando 2 passos para trás e 2 para a frente.
O segredo (`offlineSecret`, 20 bytes em Base32 sem preenchimento) nasce na aprovação do vínculo. O
aparelho o guarda cifrado. O app do responsável o obtém por `GET
/v1/guardian/devices/:id/offline-secret` **(E)** e mostra o código do momento. A verificação no
aparelho da criança é local, com limite de 5 tentativas e bloqueio progressivo persistido.

## 4. Aparelhos, política e comandos (responsável)

| Método e rota | Corpo | Resposta |
| --- | --- | --- |
| `GET /v1/guardian/devices` | | `{ devices: [Device] }` |
| `GET /v1/guardian/devices/:id` | | `{ device, policyVersion, policy }` |
| `PATCH /v1/guardian/devices/:id` **(E)** | `{ childName }` | `{ device }` |
| `POST /v1/guardian/devices/:id/revoke` **(E)** | | 204 |
| `DELETE /v1/guardian/devices/:id` **(E)** | | 204, apaga aparelho e histórico |
| `DELETE /v1/guardian/devices/:id/data` **(E)** | | 204, apaga só o histórico |
| `GET /v1/guardian/devices/:id/offline-secret` **(E)** | | `{ secret }` |
| `PUT /v1/guardian/devices/:id/policy` **(E)** | `{ baseVersion, policy }` | `{ policyVersion, policy }` |
| `POST /v1/guardian/devices/:id/extra-time` **(E)** | `{ minutes }` (1 a 720) | `{ policyVersion, policy }` |
| `POST /v1/guardian/devices/:id/lock` **(E)** | `{ until?: number \| null }` | `{ policyVersion, policy }` |
| `POST /v1/guardian/devices/:id/unlock` **(E)** | | `{ policyVersion, policy }` |
| `POST /v1/guardian/devices/:id/suspension` **(E)** | `{ minutes, scopes }` (1 a 1440) | `{ policyVersion, policy }` |
| `DELETE /v1/guardian/devices/:id/suspension` **(E)** | | `{ policyVersion, policy }` |
| `GET /v1/guardian/devices/:id/apps` | | `{ day, apps: [AppEntry] }` |
| `GET /v1/guardian/devices/:id/apps/icon?package=` | | `image/png`, com `ETag` |
| `GET /v1/guardian/devices/:id/time-requests?status=` | | `{ requests: [TimeRequest] }` |
| `POST /v1/guardian/time-requests/:id/resolve` **(E)** | `{ action: "approve" \| "deny", minutes? }` | `{ request, policyVersion }` |
| `GET /v1/guardian/devices/:id/reports/summary?from=&to=` | | `ReportSummary` |
| `GET /v1/guardian/devices/:id/sessions?day=` | | `{ day, sessions: [UsageSession] }` |
| `GET /v1/guardian/devices/:id/events?from=&to=&types=&before=&limit=` | | `{ events: [Event], nextBefore }` |
| `GET /v1/guardian/devices/:id/browsing?from=&to=&before=&limit=` | | `{ entries: [BrowsingEntry], nextBefore }` |
| `GET /v1/guardian/devices/:id/export` **(E)** | | JSON com todos os dados do aparelho |

`PUT policy` recebe a política **sem** `overrides` (se vier, é ignorado). O servidor preserva os
`overrides` atuais. As rotas de comando (`extra-time`, `lock`, `unlock`, `suspension`, `resolve`)
alteram só `overrides`, não usam `baseVersion` e sempre criam uma nova versão.

Toda alteração gera registro de auditoria e a mensagem `sync_now` para o aparelho.

### 4.1 Device

```json
{
  "id": "uuid", "status": "pending | active | revoked",
  "childName": "João", "deviceName": "Moto G de João",
  "model": "moto g54", "manufacturer": "motorola", "androidRelease": "14", "sdkInt": 34,
  "appVersion": "1.0.0", "timezone": "America/Fortaleza",
  "confirmCode": "4821", "relink": false,
  "createdAt": 0, "approvedAt": 0, "revokedAt": null,
  "lastSyncAt": 0, "online": true, "today": "2026-11-17",
  "managementMode": "standard | device_admin | device_owner",
  "policyVersion": 12, "appliedPolicyVersion": 12, "policyAppliedAt": 0,
  "pendingTimeRequests": 0,
  "state": { }
}
```
`confirmCode` e `relink` só existem em `pending`. `online` é verdadeiro quando o aparelho tem
WebSocket aberto ou sincronizou há menos de 2 minutos. `today` é o dia da cota corrente no fuso da
política, calculado pelo servidor. `state` é o último `status` enviado pelo aparelho (5.2) acrescido
de `reportedAt` e do resumo do dia: `day`, `quotaUsedMs`, `totalUsedMs`, `limitMs`, `extraMs`,
`remainingMs`, `limitReachedAt`. É `null` enquanto o aparelho não sincronizou.

### 4.2 Política

Documento completo, na versão `schema: 1`:

```json
{
  "schema": 1,
  "timezone": "America/Fortaleza",
  "dailyLimit": {
    "enabled": true,
    "minutes": 150,
    "perWeekday": { "6": 240, "7": 240 },
    "resetTime": "00:00",
    "warnAtMinutes": [15, 5]
  },
  "allowedHours": {
    "enabled": false,
    "windows": [ { "days": [1, 2, 3, 4, 5], "start": "07:00", "end": "20:30" } ]
  },
  "blockPeriods": [
    { "id": "uuid", "label": "Hora de dormir", "enabled": true, "kind": "weekly",
      "days": [1, 2, 3, 4, 5, 6, 7], "start": "21:00", "end": "07:00" },
    { "id": "uuid", "label": "Estudo para a prova", "enabled": true, "kind": "once",
      "startAt": 0, "endAt": 0 }
  ],
  "apps": {
    "defaultForNewApps": "allowed",
    "rules": {
      "com.whatsapp": { "state": "exception", "countsTowardLimit": false, "dailyLimitMinutes": null },
      "com.example.jogo": { "state": "blocked" },
      "com.google.android.youtube": { "state": "allowed", "dailyLimitMinutes": 45 }
    }
  },
  "web": {
    "managedBrowser": true, "logHistory": true, "safeDns": true, "safeSearch": true,
    "mode": "blocklist",
    "blockedDomains": [], "allowedDomains": [],
    "blockedCategories": ["adult", "gambling"]
  },
  "protection": {
    "lockOnTamper": false,
    "blockUninstall": true, "blockSafeBoot": true, "blockFactoryReset": true,
    "blockDateTimeChange": true, "blockAddUser": true,
    "blockUnknownSources": false, "blockUsbDebugging": false
  },
  "overrides": {
    "extraTime": [ { "id": "uuid", "day": "2026-11-17", "minutes": 30, "grantedAt": 0 } ],
    "manualLock": { "active": false, "until": null, "setAt": null },
    "suspension": { "until": 0, "scopes": [], "setAt": null }
  }
}
```

Regras e validação:

- `timezone`: identificador IANA. Na aprovação o servidor usa o fuso informado pelo aparelho.
- `dailyLimit.minutes` e valores de `perWeekday`: 0 a 1440. `perWeekday` é opcional e sobrepõe
  `minutes` para os dias listados. `0` significa sem tempo livre (só exceções).
- `dailyLimit.resetTime`: o **dia da cota** `D` vai de `D` no horário de reinício até `D+1` no
  mesmo horário. Com reinício às `04:00`, o uso às `02:00` do dia 18 pertence ao dia da cota 17. O
  dia da semana usado em `perWeekday` é o do dia da cota.
- `dailyLimit.warnAtMinutes`: até 4 valores de 1 a 120. Avisos locais para a criança.
- `allowedHours`: quando `enabled`, o uso só é permitido dentro de alguma janela do dia da semana
  corrente. Um dia sem janela fica bloqueado o dia inteiro. `start < end`, no mesmo dia.
- `blockPeriods`: até 50. `kind: "weekly"` usa `days`, `start`, `end`. Se `start > end` o período
  atravessa a meia-noite e `days` indica o dia em que ele **começa**. `kind: "once"` usa `startAt`
  e `endAt`. `label` com até 60 caracteres.
- Horários de `allowedHours` e `blockPeriods` usam o relógio local do fuso da política e não são
  deslocados por `resetTime`.
- `apps.rules`: chave é o nome do pacote. `state` obrigatório. `countsTowardLimit` só tem efeito em
  `exception` (padrão `false`). `dailyLimitMinutes` é um limite próprio do app (1 a 1440) e vale
  para `allowed` e `exception`. Pacote sem regra é tratado como `allowed`, exceto quando
  `defaultForNewApps` é `blocked` e o app não é de sistema: aí fica bloqueado até o responsável
  decidir.
- O navegador gerenciado aparece como o pacote virtual `com.parentalynx.app.browser`.
- `web.mode`: em `blocklist` tudo é permitido menos `blockedDomains`, `blockedCategories` e o que o
  DNS filtrado recusar. Em `allowlist` só `allowedDomains` é permitido. Domínios são comparados por
  sufixo: `exemplo.com` cobre `www.exemplo.com`. Até 500 domínios por lista.
- `web.blockedCategories`: `adult`, `gambling`, `social`, `video`, `games`. As categorias usam uma
  lista básica embutida de domínios conhecidos, que não é exaustiva. `safeDns` consulta o resolvedor
  familiar (conteúdo adulto e malware).
- `protection.lockOnTamper`: se o controle estiver degradado (permissão essencial revogada) e ainda
  houver meio de bloquear, bloqueia tudo que não for exceção. As demais chaves só têm efeito no
  modo Device Owner.
- `overrides.extraTime`: vale só para o `day` indicado. O servidor remove entradas com mais de 2
  dias.
- `overrides.manualLock`: bloqueio imediato. `until` nulo significa até desbloquear manualmente.
- `overrides.suspension`: ativa enquanto `until` for maior que o instante atual. `scopes` é um
  subconjunto de `dailyLimit`, `schedules`, `appBlocks`.

### 4.3 Avaliação da política (ordem de precedência)

Entrada: pacote, instante, uso do dia. Saída: permitido ou bloqueado, com motivo e liberação.

1. Pacote essencial (ver `02-arquitetura.md`): **permitido**, sempre.
2. Sem política ativa: permitido.
3. Resolve a regra do pacote (explícita, ou o padrão descrito acima).
4. `manualLock` ativo e regra diferente de `exception`: bloqueado, motivo `manual_lock`.
5. `lockOnTamper` ativo, controle degradado e regra diferente de `exception`: bloqueado, motivo
   `tamper_lock`.
6. Regra `blocked` (explícita ou por app novo), sem suspensão de `appBlocks`: bloqueado, motivo
   `app_blocked` ou `new_app`.
7. Limite próprio do app atingido, sem suspensão de `dailyLimit`: bloqueado, motivo `app_limit`,
   liberação no próximo reinício da cota.
8. Regra `exception`: **permitido**.
9. Fora de `allowedHours` ou dentro de um `blockPeriod`, sem suspensão de `schedules`: bloqueado,
   motivo `schedule`, liberação no fim do período.
10. Limite diário ativo e `quotaUsedMs >= limite efetivo`, sem suspensão de `dailyLimit`:
    bloqueado, motivo `daily_limit`, liberação no próximo reinício da cota.
11. Permitido.

Limite efetivo do dia = minutos do dia da semana + soma de `extraTime` do dia.

Contagem: `totalUsedMs` soma o tempo em primeiro plano dos apps rastreados (com ícone no launcher
ou instalados pelo usuário). `quotaUsedMs` soma só o tempo que consome a cota: apps `allowed` e
exceções com `countsTowardLimit`, e somente enquanto o limite diário não está suspenso. Pacotes
essenciais nunca consomem cota. O tempo no launcher, na interface do sistema e no próprio
ParentaLynx (fora do navegador) não é contado. A classificação completa está em
`02-arquitetura.md`, seção 4.1.

Estado do aparelho (`lock.state`): `manual_lock`, senão `tamper_lock`, senão `schedule`, senão
`daily_limit`, senão `none`. É o motivo que atingiria um app `allowed` comum naquele instante.

## 5. Rotas do aparelho (token `dv_`)

| Método e rota | Corpo | Resposta |
| --- | --- | --- |
| `POST /v1/device/sync` | `SyncRequest` | `SyncResponse` |
| `PUT /v1/device/apps` | `{ full: true, apps: [InventoryApp] }` | `{ needIcons: [package] }` |
| `PUT /v1/device/apps/icon?package=&hash=` | PNG, até 64 KiB | 204 |
| `POST /v1/device/admin-verify` | `{ password }` | `{ ok: true }` |
| `POST /v1/device/unlink` | `{ password }` | 204, revoga o aparelho |
| `GET /v1/device/stream` (WebSocket) | | ver seção 7 |

Token revogado responde `device_revoked` em qualquer rota.

### 5.1 Inventário

**InventoryApp**: `{ "package": "com.whatsapp", "label": "WhatsApp", "category": "communication",
"system": false, "launchable": true, "essential": false, "versionName": "2.24", "installedAt": 0,
"updatedAt": 0, "iconHash": "hex16|null" }`

Categorias: `games`, `social`, `video`, `audio`, `image`, `news`, `maps`, `productivity`,
`communication`, `browser`, `system`, `other`. Vêm de `ApplicationInfo.category`, do papel do app
(discador, SMS, navegador) e da marca de app de sistema. Não há categoria "escolar" identificável
pelo sistema: o responsável marca os apps escolares como exceção.

`essential: true` indica pacote que o aparelho nunca bloqueia. O painel mostra o app como
"essencial do sistema" e não deixa mudar o estado.

Com `full: true`, pacotes ausentes da lista são marcados como removidos. `needIcons` lista os
pacotes cujo ícone o servidor não tem na versão `iconHash`.

**AppEntry** (visão do responsável): os campos de `InventoryApp` mais `iconUrl` (caminho relativo
autenticado, ou `null`), `state`, `countsTowardLimit`, `dailyLimitMinutes`, `todayMs`, `weekMs`,
`removed`.

### 5.2 Sincronização

**SyncRequest**
```json
{
  "sentAt": 0,
  "policyVersion": 12,
  "policyAppliedAt": 0,
  "status": {
    "managementMode": "standard",
    "permissions": { "usageAccess": true, "accessibility": true, "overlay": false,
      "notifications": true, "batteryOptimizationIgnored": true, "deviceAdmin": false,
      "exactAlarms": true },
    "enforcement": { "active": true, "issues": [] },
    "lock": { "state": "none", "releaseAt": null },
    "foregroundApp": "com.whatsapp", "screenOn": true, "batteryPercent": 80,
    "appVersion": "1.0.0", "sdkInt": 34, "timezone": "America/Fortaleza", "tzOffsetMin": -180,
    "clockTrusted": true
  },
  "days": [
    { "day": "2026-11-17", "quotaUsedMs": 0, "totalUsedMs": 0, "limitMs": 9000000, "extraMs": 0,
      "limitReachedAt": null, "firstUseAt": 0, "lastUseAt": 0,
      "apps": [ { "package": "com.whatsapp", "ms": 0, "opens": 0 } ],
      "hourly": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] }
  ],
  "sessions": [ { "id": "uuid", "package": "com.whatsapp", "start": 0, "end": 0,
    "day": "2026-11-17", "tzOffsetMin": -180 } ],
  "events": [ { "id": "uuid", "type": "blocked_attempt", "ts": 0, "package": "com.example.jogo",
    "data": { "reason": "app_blocked" } } ],
  "browsing": [ { "id": "uuid", "ts": 0, "url": "https://exemplo.com/a", "domain": "exemplo.com",
    "title": "Exemplo", "blocked": false, "reason": null } ]
}
```

- `days`: o último elemento é sempre o dia corrente. Dias anteriores entram enquanto tiverem
  alteração ainda não confirmada. `limitMs` é o limite efetivo (com tempo extra) ou `null` se o
  limite está desligado. `hourly` tem 24 posições com o tempo total por hora local.
- Limites por requisição: 500 sessões, 500 eventos, 500 registros de navegação, 8 dias. Excedente
  vai na sincronização seguinte.
- `enforcement.issues`: `accessibility_disabled`, `usage_access_missing`, `overlay_missing`,
  `notifications_disabled`, `battery_optimized`, `suspend_failed`, `policy_invalid`,
  `clock_untrusted`.
- `lock.state`: `none`, `daily_limit`, `schedule`, `manual_lock`, `tamper_lock`.

**SyncResponse**
```json
{
  "serverTime": 0,
  "policyVersion": 13,
  "policy": null,
  "ack": { "sessions": ["uuid"], "events": ["uuid"], "browsing": ["uuid"], "days": ["2026-11-16"] },
  "reconcile": { "day": "2026-11-17", "quotaUsedMs": 0, "totalUsedMs": 0 },
  "timeRequests": [ { "id": "uuid", "status": "approved", "grantedMinutes": 30, "resolvedAt": 0 } ],
  "childName": "João", "guardianName": "Maria",
  "lowTimeMinutes": 10,
  "needAppInventory": false
}
```

- `policy` vem preenchida quando a versão do servidor é maior que a informada.
- `ack` confirma o que foi gravado. Itens são idempotentes pelo `id` do cliente: reenvio não
  duplica. `ack.days` lista os dias **anteriores ao corrente** já gravados.
- `reconcile`: valores que o servidor tem para o dia corrente informado. O servidor guarda sempre
  o **maior** valor recebido para cada contador. O aparelho adota o maior entre o local e o do
  servidor.
- `timeRequests`: pedidos das últimas 24 horas, identificados pelo `id` do evento `time_request`.
- `needAppInventory`: o servidor ainda não tem inventário, ou ele tem mais de 24 horas.

### 5.3 Eventos

| `type` | `data` | Alerta gerado |
| --- | --- | --- |
| `blocked_attempt` | `{ reason }` (motivos de 4.3), com `package` | `blocked_app_attempt`, no máximo um por app a cada 10 min |
| `limit_reached` | `{ day, limitMs, quotaUsedMs }` | `limit_reached` |
| `low_time` | `{ remainingMs, thresholdMinutes }` | `low_time` |
| `app_limit_reached` | `{ limitMs }`, com `package` | |
| `lock_started` | `{ reason, releaseAt }` | |
| `lock_ended` | `{ reason }` | |
| `policy_applied` | `{ version }` | |
| `policy_apply_failed` | `{ version, error }` | `enforcement_failure` |
| `enforcement_issue` | `{ issue, detail }` | `enforcement_failure` |
| `permission_changed` | `{ permission, granted }` | `permission_changed` |
| `time_request` | `{ minutes, message }` (ambos opcionais) | `time_request` |
| `local_override` | `{ minutes, method }` com `password` ou `offline_code` | `security_event` |
| `admin_auth_failed` | `{ method, attempts }` | `security_event` |
| `clock_changed` | `{ kind, deltaMs, timezone }` com `time` ou `timezone` | `security_event` |
| `unlinked_locally` | `{ method }` | `security_event` |
| `device_boot` | `{ }` | |
| `device_shutdown` | `{ }` | |
| `agent_started` | `{ reason }` | |
| `management_mode_changed` | `{ from, to }` | `security_event` |
| `app_installed` | `{ label }`, com `package` | `new_app_installed` |
| `app_removed` | `{ label }`, com `package` | |

O evento `low_time` é emitido pelo aparelho uma vez por dia quando o restante cruza
`lowTimeMinutes` da conta (recebido em `SyncResponse.lowTimeMinutes`, padrão 10).

Alertas gerados pelo próprio servidor: `sync_stale` (sem sincronizar há mais de
`syncStaleMinutes`), `device_offline` (há mais de `offlineHours`), `policy_changed` (política
alterada por outra sessão), `device_linked` (vínculo pendente, aprovado ou revogado).

**Event** (visão do responsável): `{ "id": 0, "type": "...", "ts": 0, "package": "...|null",
"label": "...|null", "data": {} }`

## 6. Relatórios

**ReportSummary** (`from` e `to` inclusivos, no máximo 92 dias)
```json
{
  "from": "2026-11-11", "to": "2026-11-17", "timezone": "America/Fortaleza",
  "totals": { "totalMs": 0, "quotaMs": 0, "daysWithUse": 0, "avgPerDayMs": 0,
    "blockedAttempts": 0, "sessions": 0, "opens": 0 },
  "daily": [ { "day": "2026-11-11", "totalMs": 0, "quotaMs": 0, "limitMs": null,
    "limitReachedAt": null, "blockedAttempts": 0, "firstUseAt": null, "lastUseAt": null } ],
  "apps": [ { "package": "com.whatsapp", "label": "WhatsApp", "category": "communication",
    "totalMs": 0, "opens": 0, "days": 0, "blockedAttempts": 0 } ],
  "categories": [ { "category": "games", "totalMs": 0 } ],
  "hourly": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  "blockedByApp": [ { "package": "com.example.jogo", "label": "Jogo", "count": 0 } ]
}
```
`daily` tem uma entrada para cada dia do intervalo, com zeros onde não houve uso. `apps`,
`categories` e `blockedByApp` vêm em ordem decrescente.

**UsageSession**: `{ "package", "label", "category", "start", "end", "durationMs", "tzOffsetMin" }`

**BrowsingEntry**: `{ "id", "ts", "url", "domain", "title", "blocked", "reason" }` com `reason` em
`domain_blocked`, `category`, `safe_dns`, `not_in_allowlist` ou `null`.

**TimeRequest**: `{ "id", "deviceId", "childName", "createdAt", "minutes", "message", "status",
"grantedMinutes", "resolvedAt" }` com `status` em `pending`, `approved`, `denied`, `expired`. Pedido
pendente expira em 24 horas. Aprovar adiciona `grantedMinutes` ao `extraTime` do dia corrente.

## 7. Tempo real (WebSocket)

Mensagens são objetos JSON com `type`. O cliente envia `{ "type": "ping" }` a cada 30 segundos e o
servidor responde `{ "type": "pong" }`. Conexão sem tráfego por 90 segundos é encerrada. Token
inválido fecha com o código 4401.

**Responsável** (`/v1/guardian/stream`), servidor para cliente:
`hello { serverTime }`, `device_updated { deviceId }`, `alert { alert }`,
`link_pending { deviceId }`, `link_resolved { deviceId, status }`,
`policy_applied { deviceId, version }`, `time_request { deviceId, requestId }`.

**Aparelho** (`/v1/device/stream`), servidor para cliente:
`hello { serverTime }`, `sync_now { reason }`, `revoked { }`.

O WebSocket é só um aviso para sincronizar. O estado sempre vem das rotas HTTP, então perder uma
mensagem não causa inconsistência.

## 8. Retenção e exclusão

- Sessões, eventos, navegação e alertas: apagados após `retentionDays` (padrão 90).
- Agregados diários: 400 dias. Auditoria: 365 dias.
- Tarefa de limpeza diária no servidor.
- `DELETE .../data` apaga o histórico de um aparelho. `DELETE .../devices/:id` apaga o aparelho.
  `DELETE /v1/guardian/account` apaga tudo. As três exigem autenticação administrativa e ficam na
  auditoria (a da conta, por definição, não deixa rastro além do log do servidor).
- Campos sensíveis (URL e título de navegação, `data` de eventos, segredo offline) são cifrados em
  repouso com AES-256-GCM e chave fornecida por variável de ambiente.

## 9. Esclarecimentos fixados na implementação

Pontos que o texto acima deixava em aberto e que o servidor, o agente e o app tratam assim:

**Erros**
- `validation_error` traz `details.fields` (nomes como `policy.dailyLimit.minutes`) e
  `details.issues` (`[{ field, message }]`).
- Código de vinculação errado responde `invalid_credentials` (401). Vencido, usado ou cancelado
  responde `code_expired` (410).
- `invalid_credentials` de `admin-verify` traz `details.attemptsLeft`.
- `rate_limited` e `account_locked` também enviam o cabeçalho `Retry-After`.
- Aparelho de outra conta responde `forbidden`. Aparelho inexistente responde `not_found`.

**Vinculação**
- `code` em `POST pairing-codes` vem com 8 caracteres, sem hífen. O app formata.
- O vínculo pendente é listado com `id` igual ao `linkId`. Na aprovação sem reaproveitamento o
  aparelho mantém esse `id`. Com reaproveitamento, `approve` devolve o `id` do cadastro antigo, a
  política e a versão ficam, `appliedPolicyVersion` volta a zero e o segredo offline é trocado.
- `link_resolved` leva `{ deviceId, linkId, status }`.

**Política**
- Em `PUT policy`, seção ausente mantém o valor atual e seção presente substitui por inteiro.
  Salvar sem mudança não cria versão.
- As regras de app saem normalizadas com os três campos. `allowed` sempre conta para o limite.
  `blocked` nunca conta e perde o limite próprio.
- Uma regra explícita `{"state": "allowed"}` é a aprovação de um app quando `defaultForNewApps` é
  `blocked`, e por isso é gravada mesmo sendo igual ao padrão.
- `approve` de um pedido de tempo sem `minutes` usa o que a criança pediu, ou 15.

**Sincronização**
- `policy` vem preenchida sempre que a versão informada pelo aparelho é diferente da do servidor.
- Só `device_revoked` desativa o controle no aparelho. Um 401 `unauthorized` apenas registra o
  erro, para um proxy mal configurado não desligar o controle parental.
- O evento `unlinked_locally` revoga o cadastro do aparelho no servidor e entra na auditoria: o
  painel não mostra como ativo um aparelho que deixou de aplicar as regras.
- `permission_changed` com `granted: true` gera alerta sem notificação (`notify: false`). A
  revogação notifica.
- A liberação local (`grantLocalOverride`) passa por cima de bloqueio manual, adulteração,
  horários e limite diário, mas não de app bloqueado. O tempo nesse período não consome cota.
- `hourly` aceita até 2 horas por posição.

**Consultas**
- `from` e `to` de `events` e `browsing` são dias `YYYY-MM-DD`. `before` é o `id`. A ordem é
  decrescente.
- `alerts` com `after` vem em ordem crescente. Sem ele, decrescente. A sessão que causou um
  alerta não o vê.
- Inatividade no WebSocket fecha com o código 4408.
