#!/usr/bin/env bash
# Publica o backend em um VPS Ubuntu ou Debian, com Docker e HTTPS automatico (Caddy).
#
# Uso (no Git Bash, no Windows, ou em qualquer terminal Linux ou macOS):
#   bash backend/deploy/publicar.sh usuario@servidor [dominio]
#
# Primeira vez: informe o dominio (por exemplo api.exemplo.com.br), que ja precisa apontar
# para o servidor. O script instala o Docker, cria o .env com uma chave de cifra nova, mostra
# essa chave uma unica vez e agenda o backup diario.
#
# Atualizacoes: basta o servidor. O script envia o codigo do ultimo commit e reconstroi a API.
# O banco e os certificados ficam em volumes do Docker e nao sao tocados.
#
# O usuario do SSH precisa ser root ou ter sudo sem senha. Guia: docs/08-servidor-vps.md.
set -euo pipefail

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

if [[ $# -lt 1 || $# -gt 2 || "$1" == -* ]]; then
  usage
  exit 64
fi

TARGET="$1"
DOMAIN="${2:-}"

# So o nome do dominio, sem esquema, porta ou caminho.
if [[ -n "$DOMAIN" && ! "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]; then
  echo "Domínio inválido: '$DOMAIN'. Informe só o nome, sem https://, por exemplo api.exemplo.com.br." >&2
  exit 64
fi

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Publica exatamente o que esta no commit, para saber sempre qual versao esta no ar.
if [[ -n "$(git status --porcelain -- backend)" ]]; then
  echo "Há alterações não confirmadas em backend/:" >&2
  git status --short -- backend >&2
  echo "Faça o commit antes de publicar. O script envia só o que está no commit." >&2
  exit 1
fi

RELEASE="$(git rev-parse --short HEAD)"
SSH_OPTS=(-o ServerAliveInterval=30 -o ConnectTimeout=15)

echo "==> Enviando o backend (commit $RELEASE) para $TARGET"
# core.autocrlf=false: os arquivos saem com LF, como no repositorio, mesmo vindo do Windows.
git -c core.autocrlf=false archive --format=tar.gz HEAD backend \
  | ssh "${SSH_OPTS[@]}" "$TARGET" 'cat > /tmp/parentalynx-backend.tar.gz'

echo "==> Instalando e subindo no servidor"
# O script do servidor sai do proprio pacote e roda como arquivo, nao pela entrada padrao:
# comandos como "docker compose exec" leriam o resto do script se ele viesse por ali.
REMOTE_RUN="tmp=\$(mktemp) && tar -xzf /tmp/parentalynx-backend.tar.gz -O backend/deploy/no-servidor.sh > \"\$tmp\" || exit 1
if [ \"\$(id -u)\" = 0 ]; then run=''; else run='sudo -n'; fi
rc=0; \$run bash \"\$tmp\" '$DOMAIN' '$RELEASE' < /dev/null || rc=\$?
rm -f \"\$tmp\"; exit \$rc"
ssh "${SSH_OPTS[@]}" "$TARGET" "$REMOTE_RUN"

# Conferencia de fora, como os celulares vao acessar: DNS, portas e certificado.
if [[ -n "$DOMAIN" ]]; then
  echo "==> Conferindo de fora: https://$DOMAIN/health"
  if curl -fsS --max-time 15 "https://$DOMAIN/health" >/dev/null; then
    echo "O servidor responde pela internet."
  else
    echo "O servidor respondeu dentro do VPS, mas não daqui. Confira o firewall do provedor" >&2
    echo "(portas 80 e 443) e se o DNS já propagou: nslookup $DOMAIN" >&2
    exit 1
  fi
fi
