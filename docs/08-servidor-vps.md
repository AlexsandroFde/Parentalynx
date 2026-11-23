# Servidor em um VPS

Este guia põe o backend no ar em um VPS, com domínio e HTTPS, para que os aplicativos falem com
ele sem ninguém digitar endereço. O endereço do servidor é fixo no código do app
(`AppConfig.serverUrl`) e o app não oferece a troca.

Um IP de rede local não serve para o uso real: o celular da criança sai do Wi-Fi de casa (dados
móveis, escola) e o aparelho grava o endereço do servidor no momento da vinculação.

## 1. O que é preciso

- **VPS** com Ubuntu 24.04, Ubuntu 22.04 ou Debian 12, IPv4 público e acesso root por SSH.
  1 vCPU, 1 GB de RAM e 10 GB de disco bastam para algumas famílias. Qualquer provedor que
  entregue isso serve.
- **Domínio** ou subdomínio sob seu controle, por exemplo `api.suafamilia.com.br`. Domínios
  `.br` são registrados no Registro.br.
- **Chave SSH** no seu computador (seção 3).

Os dados são de crianças. Antes de escolher o provedor, veja em
[06-privacidade-lgpd.md](06-privacidade-lgpd.md) o item sobre servidor e backups fora do país.

## 2. Apontar o domínio para o VPS

No painel de DNS do domínio, crie um registro **A** com o nome escolhido (por exemplo `api`) e o
IP público do VPS. Se o VPS tiver IPv6, crie também o registro **AAAA**.

Se o DNS for da Cloudflare, deixe o registro como "somente DNS" (nuvem cinza). O certificado é
emitido pelo próprio servidor.

Confira antes de seguir. A resposta precisa ser o IP do VPS:

```bash
nslookup api.suafamilia.com.br
```

A propagação costuma levar minutos, mas pode levar algumas horas.

## 3. Acesso por SSH com chave

No Git Bash ou no PowerShell:

```bash
ssh-keygen -t ed25519
```

Cadastre o conteúdo de `~/.ssh/id_ed25519.pub` no painel do provedor ao criar o VPS (campo "SSH
key"). Se o VPS já existir, rode `ssh-copy-id root@IP_DO_VPS` no Git Bash. Confira:

```bash
ssh root@IP_DO_VPS
```

O script funciona com o usuário `root` ou com um usuário que tenha `sudo` sem senha (caso de
provedores que entregam o usuário `ubuntu`). Se o SSH usar outra porta, crie um apelido em
`~/.ssh/config` e use o apelido no lugar de `root@IP_DO_VPS`.

## 4. Publicar

O script envia o que está no último commit. Confirme as alterações de `backend/` antes; com
alterações pendentes nessa pasta ele para e avisa.

Na raiz do repositório, no Git Bash:

```bash
bash backend/deploy/publicar.sh root@IP_DO_VPS api.suafamilia.com.br
```

Na primeira vez o script:

1. instala o Docker pelo repositório oficial, se ainda não houver;
2. copia o backend para `/opt/parentalynx/backend`;
3. cria o `.env` com o domínio e uma chave de cifra nova;
4. confere se o domínio aponta para o servidor;
5. libera as portas 80 e 443 no `ufw`, se ele estiver ativo;
6. constrói a imagem e sobe a API e o Caddy, que obtém o certificado HTTPS;
7. confere a API e o HTTPS dentro do VPS e depois de fora, como os celulares vão acessar;
8. agenda o backup diário do banco.

No fim, ele mostra a **chave de cifra do banco** uma única vez. Guarde-a em um gerenciador de
senhas, fora do servidor. Sem ela, os backups não podem ser lidos. Uma cópia fica em
`/opt/parentalynx/backend/.env`, que só o root lê.

Se o provedor tiver firewall no painel (grupos de segurança, por exemplo), libere nele as portas
22, 80 e 443 (TCP) e 443 (UDP).

Conferir a qualquer momento: `curl https://api.suafamilia.com.br/health`.

## 5. Pôr o endereço no app

Em `app/lib/app/config/app_config.dart`, troque o valor de `serverUrl` pelo endereço do servidor:

```dart
static const String serverUrl = 'https://api.suafamilia.com.br';
```

Depois compile normalmente (`flutter build apk --release`, ou `flutter run` para depurar no
celular). Todos os builds, de depuração e de produção, passam a usar esse endereço. Ele aparece
só para leitura em Mais, "Servidor em uso". Trocar de servidor exige mudar o valor e instalar o
app de novo.

O build de produção só fala HTTPS. Com o valor de testes (`http://10.0.2.2:8080`), o app de
produção não conecta.

**Aparelhos já vinculados a outro endereço** (por exemplo o IP do computador, nos testes): o
aparelho da criança guarda o endereço da vinculação. Desvincule-o e vincule de novo depois de
instalar o app novo.

A assinatura do APK de produção está em [04-instalacao.md](04-instalacao.md), seção 3.2.

## 6. Atualizar o servidor

Depois de confirmar as alterações:

```bash
bash backend/deploy/publicar.sh root@IP_DO_VPS
```

O domínio só é preciso na primeira vez. A API fica fora do ar por alguns segundos durante a
troca. O banco e os certificados ficam em volumes do Docker e não são tocados. A cada
publicação as imagens base (Node e Caddy) são atualizadas, o que traz as correções de segurança
delas.

A versão anterior fica em `/opt/parentalynx/backend.anterior`. Para voltar a ela:

```bash
ssh root@IP_DO_VPS
cd /opt/parentalynx
mv backend backend.descartada && mv backend.anterior backend
cd backend && docker compose up -d --build
```

As migrações de banco aplicadas pela versão nova não são desfeitas. Voltar de versão só é seguro
quando a versão nova não trouxe migração.

## 7. Backups

Todo dia às 3h30 (horário do servidor, normalmente UTC) o `cron` roda
`backend/deploy/backup.sh`, que grava uma cópia consistente do banco em
`/opt/parentalynx/backups` e apaga as com mais de 14 dias. O registro fica em
`/var/log/parentalynx-backup.log`.

Rodar agora:

```bash
ssh root@IP_DO_VPS bash /opt/parentalynx/backend/deploy/backup.sh
```

Os backups ficam no mesmo VPS e não protegem contra a perda dele. Copie a pasta para o seu
computador de tempos em tempos:

```bash
scp -r root@IP_DO_VPS:/opt/parentalynx/backups ./backups-vps
```

Restaurar um backup (substitui o banco atual):

```bash
ssh root@IP_DO_VPS
cd /opt/parentalynx/backend
docker compose stop api
docker compose run --rm --no-deps --user root -v /opt/parentalynx/backups:/backups:ro api \
  sh -c 'gunzip -c /backups/ARQUIVO.db.gz > /data/parentalynx.db \
    && rm -f /data/parentalynx.db-wal /data/parentalynx.db-shm \
    && chown node:node /data/parentalynx.db'
docker compose start api
```

O backup só é legível com a mesma `DATA_ENCRYPTION_KEY` do `.env`. Em um VPS novo, crie o `.env`
com a chave guardada antes de restaurar.

## 8. Manutenção

| Tarefa | Comando, dentro de `/opt/parentalynx/backend` no VPS |
| --- | --- |
| Ver os logs da API | `docker compose logs -f api` |
| Ver os logs do HTTPS | `docker compose logs -f caddy` |
| Estado dos contêineres | `docker compose ps` |
| Reiniciar a API | `docker compose restart api` |
| Mudar uma variável | edite o `.env` e rode `docker compose up -d` |

Os logs têm tamanho limitado (3 arquivos de 10 MB por contêiner). O Caddy renova o certificado
sozinho. As atualizações de segurança do sistema operacional ficam por conta do VPS: no Ubuntu,
o pacote `unattended-upgrades` já vem ativo.

## 9. Problemas comuns

| Sintoma | Causa provável e solução |
| --- | --- |
| "o domínio ainda não aponta para nenhum endereço" | Falta o registro A ou ele ainda não propagou. Confira com `nslookup`. |
| "o HTTPS não respondeu" | Portas 80 e 443 fechadas no firewall do provedor, ou DNS apontando para outro IP. Depois de corrigir, rode o script de novo. |
| HTTPS funciona no VPS, mas não de fora | Firewall do provedor ou DNS ainda propagando no seu computador. |
| "sudo: a password is required" | O usuário do SSH precisa de `sudo` sem senha. Use `root` ou configure o `sudo`. |
| Várias tentativas de certificado falharam | A Let's Encrypt limita falhas seguidas. Corrija o DNS ou o firewall e espere uma hora. |
| "Há alterações não confirmadas em backend/" | Faça o commit e rode de novo. |
| O app diz que não consegue falar com o servidor | Abra `https://SEU_DOMINIO/health` no navegador do celular. Se abrir, confira se `AppConfig.serverUrl` tem esse endereço e se o APK instalado foi compilado depois da troca. |

## O que foi testado

- A API e o Caddy subiram com o `docker-compose.yml` no Docker 29, com HTTPS (certificado interno
  para `localhost`), redirecionamento de HTTP para HTTPS, HSTS, HTTP/3 anunciado e WebSocket
  passando pelo proxy. A API roda com o usuário sem privilégios `node`.
- O `backup.sh` gerou cópias íntegras (`PRAGMA integrity_check`), inclusive com dados gravados
  segundos antes, e removeu o arquivo temporário do volume.
- O `publicar.sh` e o `no-servidor.sh` rodaram por SSH contra um contêiner Ubuntu 24.04, com o
  Docker do servidor simulado: recusa sem domínio na primeira vez, instalação, atualização por
  usuário com `sudo` (o `.env` e a chave foram preservados), troca de domínio com aviso,
  instalação do `cron` e agendamento do backup.
- A instalação do Docker pelo repositório oficial foi feita de verdade no mesmo Ubuntu 24.04.

Não foram testados: a emissão de certificado pela Let's Encrypt (precisa de domínio público), a
publicação em um VPS real e o procedimento de restauração da seção 7.
