# Backend do ParentaLynx

Servidor que guarda as contas dos responsáveis, vincula os aparelhos, distribui a política de
controle parental, recebe o uso e os eventos dos aparelhos e gera relatórios e alertas.

O contrato com os aplicativos está em [`docs/03-protocolo.md`](../docs/03-protocolo.md) e as
decisões de arquitetura em [`docs/02-arquitetura.md`](../docs/02-arquitetura.md).

## Requisitos

- Node.js 24.7 ou superior. O servidor usa recursos nativos dessa versão: execução direta de
  TypeScript, SQLite (`node:sqlite`) e Argon2 (`node:crypto`).
- Nenhum serviço externo. O banco é um arquivo SQLite.

## Rodar localmente

```bash
cd backend
npm install
npm start
```

O servidor sobe em `http://localhost:8080`. Sem `DATA_ENCRYPTION_KEY`, o modo de desenvolvimento
gera uma chave e a grava ao lado do banco (`data/parentalynx.db.key`), com um aviso no console.

Para configurar, copie `.env.example` para `.env`. Os scripts `npm start` e `npm run dev` leem
esse arquivo quando ele existe. `npm run dev` reinicia o servidor a cada alteração no código.

Conferir que está no ar:

```bash
curl http://localhost:8080/health
```

Para testar com o app no emulador Android, o endereço do computador é `http://10.0.2.2:8080`.
Em um aparelho físico na mesma rede, use o IP do computador. Builds de produção do app só aceitam
HTTPS.

## Variáveis de ambiente

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `NODE_ENV` | `development` | `production` exige `DATA_ENCRYPTION_KEY`. |
| `PORT` | `8080` | Porta de escuta. |
| `HOST` | `0.0.0.0` | Endereço de escuta. |
| `DATABASE_PATH` | `./data/parentalynx.db` | Arquivo SQLite. A pasta é criada se não existir. |
| `DATA_ENCRYPTION_KEY` | (vazia) | Base64 de 32 bytes. Chave da cifra de campos sensíveis. |
| `TRUST_PROXY` | `false` | `true` atrás de proxy reverso, para o limite por IP usar o endereço real. |
| `LOG_LEVEL` | `info` | `fatal`, `error`, `warn`, `info`, `debug`, `trace` ou `silent`. |
| `SESSION_TTL_DAYS` | `30` | Validade da sessão do responsável sem uso. |
| `ELEVATION_MINUTES` | `15` | Tempo em que a senha confirmada libera operações administrativas. |
| `PAIRING_CODE_TTL_MINUTES` | `15` | Validade do código de vinculação. |

Gerar a chave:

```bash
node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
```

Guarde a chave fora do servidor. Sem ela, endereços e títulos de navegação, dados de eventos,
textos de alertas, mensagens de pedidos de tempo e os segredos de acesso offline não podem ser
lidos. Trocar a chave não recifra os dados já gravados.

## Produção com Docker e HTTPS

O `docker-compose.yml` sobe a API e o Caddy, que termina o HTTPS com certificado automático.

1. Aponte o DNS do domínio para o servidor e libere as portas 80 e 443.
2. `cp .env.example .env` e preencha `DOMAIN` e `DATA_ENCRYPTION_KEY`.
3. `docker compose up -d --build`
4. `curl https://SEU_DOMINIO/health`

A API não é exposta diretamente: só o Caddy publica portas. O contêiner roda com o usuário sem
privilégios `node` e o banco fica no volume `api_data`.

Para usar outro proxy (Nginx, Traefik), encaminhe HTTP e WebSocket para a porta 8080 e defina
`TRUST_PROXY=true`.

## Backup e restauração

O banco é o arquivo de `DATABASE_PATH` mais os arquivos `-wal` e `-shm` que o SQLite mantém ao
lado. Não copie só o arquivo principal com o servidor rodando.

Backup consistente com o servidor no ar:

```bash
sqlite3 data/parentalynx.db ".backup 'backup/parentalynx-$(date +%F).db'"
```

Com Docker:

```bash
docker compose exec api node -e "const { DatabaseSync } = require('node:sqlite'); new DatabaseSync(process.env.DATABASE_PATH).exec(\"VACUUM INTO '/data/backup.db'\")"
docker compose cp api:/data/backup.db ./backup/parentalynx-$(date +%F).db
```

Guarde a `DATA_ENCRYPTION_KEY` junto do plano de backup, em local separado dos arquivos: um
backup sem a chave não recupera os campos cifrados, e um backup com a chave no mesmo lugar não
protege nada.

Restaurar: pare o servidor, substitua o arquivo do banco pelo backup, apague os arquivos `-wal`
e `-shm` antigos e suba de novo. As migrações pendentes são aplicadas na inicialização.

## Testes

```bash
npm test            # 169 testes, com banco em memória e relógio controlado
npm run typecheck   # verificação de tipos (tsc --noEmit)
```

Os testes sobem o servidor em processo (`app.inject`), sem abrir porta, exceto um teste de
WebSocket que usa uma porta efêmera. Cobrem: contas e política de senha, bloqueio progressivo,
recuperação, elevação, vinculação (uso único, validade, aprovação, entrega única, vários
aparelhos, reaproveitamento), política versionada, comandos, sincronização (confirmação
idempotente, reconciliação pelo maior valor, limites de lote), inventário e ícones, pedidos de
tempo, alertas e preferências, relatórios, isolamento entre contas, cifra em repouso, ausência
de segredos no log, revogação, exclusões, retenção, monitor de falta de sincronização, WebSocket
e TOTP com os vetores da RFC 6238.

## Simulador de aparelho

Para testar o painel sem um aparelho Android:

1. No app do responsável (ou pela API), gere um código de vinculação.
2. Rode:

```bash
npm run simulate -- --url http://localhost:8080 --code AB12-CD34
```

3. Aprove o aparelho no painel, conferindo o código de confirmação que o simulador mostra.

O simulador envia o inventário de 9 apps com ícones e passa a sincronizar, a cada intervalo,
com uso crescente, tentativas em apps bloqueados, aviso de limite atingido, pedidos de tempo e
visitas no navegador. Ele reage às mudanças feitas no painel: aplica a política nova, respeita
bloqueio manual, tempo extra e o limite diário, e encerra se o vínculo for revogado.

| Opção | Padrão | Descrição |
| --- | --- | --- |
| `--url` | `http://localhost:8080` | Endereço do servidor. |
| `--code` | | Código de vinculação. Sem ele, retoma o aparelho do arquivo de estado. |
| `--name` | `Aparelho simulado` | Nome do aparelho. Nomes diferentes simulam aparelhos diferentes. |
| `--interval` | `15` | Segundos entre sincronizações. |
| `--minutes-per-tick` | `5` | Minutos de uso somados a cada sincronização. |
| `--ticks` | `0` | Quantidade de sincronizações. `0` roda até ser interrompido. |
| `--state` | `./data/simulator-<nome>.json` | Arquivo onde ficam as credenciais do aparelho simulado. |

## Estrutura

```
src/
  server.ts        entrada: configuração, servidor e tarefas periódicas
  app.ts           montagem do Fastify (usada também pelos testes)
  config.ts        variáveis de ambiente
  context.ts       dependências compartilhadas (banco, cifra, hub, relógio)
  db/              conexão SQLite e migrações SQL numeradas
  core/            erros, validação, tokens e cifra, senhas, limite de taxa, calendário, TOTP
  modules/
    auth/          registro, login, recuperação, sessões, elevação
    guardian/      perfil, preferências, auditoria, exclusão da conta
    pairing/       códigos, pedido de vínculo, aprovação
    devices/       aparelhos, política, comandos, inventário para o painel, pedidos de tempo
    policy/        esquema, validação, política padrão, resumo de diferenças
    sync/          sincronização do aparelho, inventário, ícones, senha no aparelho
    reports/       relatórios, sessões, eventos, navegação, exportação
    alerts/        alertas a partir de eventos, central, monitor de falta de sincronização
    realtime/      WebSocket
    retention/     limpeza e tarefas periódicas
test/              testes com node:test
scripts/           simulador de aparelho
```

Novas migrações entram em `src/db/migrations` como `NNN_nome.sql` e são aplicadas em ordem na
inicialização.

## Segurança

- Senhas com Argon2id (19456 KiB, 2 passagens), no formato PHC. Nunca gravadas nem registradas.
- Tokens opacos de 256 bits. O banco guarda só o SHA-256.
- Operações administrativas exigem senha confirmada nos últimos 15 minutos.
- Bloqueio progressivo por tentativas de senha e limite por IP nas rotas públicas.
- Toda rota confere a posse do recurso: uma conta não acessa aparelhos de outra.
- Campos sensíveis cifrados em repouso com AES-256-GCM.
- O log registra método, caminho e status. Cabeçalho de autorização mascarado, corpos fora.
- Auditoria de todas as alterações administrativas, visível ao responsável.

## Limites conhecidos

- Um único processo. O hub de WebSocket e o limite de taxa ficam em memória, então não há
  suporte a várias instâncias atrás de um balanceador.
- Sem push de terceiros. Alertas chegam por WebSocket com o app aberto e por busca periódica.
- Recuperação de conta só pela chave de recuperação. Não há envio de e-mail.
