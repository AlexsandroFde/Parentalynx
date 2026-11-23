#!/usr/bin/env bash
# Parte do deploy que roda no VPS, como root. Quem chama e publicar.sh, que antes envia o
# codigo para /tmp/parentalynx-backend.tar.gz e tira este script de dentro do pacote.
#
# Argumentos: [dominio] [versao]. O dominio so e obrigatorio na primeira instalacao.
#
# Pode ser repetido quantas vezes for preciso: cada passo confere o que ja existe.
set -euo pipefail

DOMAIN_ARG="${1:-}"
RELEASE="${2:-desconhecida}"
BASE=/opt/parentalynx
APP="$BASE/backend"
ARCHIVE=/tmp/parentalynx-backend.tar.gz
ENV_FILE="$APP/.env"
DOMAIN_PATTERN='^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$'

log() { printf '\n==> %s\n' "$*"; }
fail() {
  printf '\nErro: %s\n' "$*" >&2
  exit 1
}

[[ -f "$ARCHIVE" ]] || fail "o pacote $ARCHIVE não chegou ao servidor."
if [[ -n "$DOMAIN_ARG" && ! "$DOMAIN_ARG" =~ $DOMAIN_PATTERN ]]; then
  fail "domínio inválido: '$DOMAIN_ARG'."
fi
if [[ ! -f "$ENV_FILE" && -z "$DOMAIN_ARG" ]]; then
  fail "primeira instalação: informe o domínio (publicar.sh usuario@servidor api.exemplo.com.br)."
fi

APT_UPDATED=""
apt_install() {
  command -v apt-get >/dev/null 2>&1 || fail "faltam pacotes ($*) e este sistema não usa apt. Instale-os e rode de novo."
  if [[ -z "$APT_UPDATED" ]]; then
    apt-get update -q >/dev/null
    APT_UPDATED=1
  fi
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$@" >/dev/null
}

# 1. Docker, pelo repositorio oficial (o pacote docker.io das distribuicoes costuma vir sem o
#    plugin compose).
install_docker() {
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    ubuntu | debian) ;;
    *) fail "sistema ${PRETTY_NAME:-desconhecido} não suportado pelo script. Use Ubuntu ou Debian, ou instale o Docker com o plugin compose e rode de novo." ;;
  esac
  log "Instalando o Docker (repositório oficial)"
  apt_install ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update -q >/dev/null
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker >/dev/null
}

if ! command -v docker >/dev/null 2>&1; then
  install_docker
elif ! docker compose version >/dev/null 2>&1; then
  fail "o Docker já está instalado, mas sem o plugin compose. Instale docker-compose-plugin (ou docker-compose-v2 no Ubuntu) e rode de novo."
fi
command -v curl >/dev/null 2>&1 || apt_install curl
if ! command -v cron >/dev/null 2>&1; then
  apt_install cron
  systemctl enable --now cron >/dev/null 2>&1 || true
fi

# 2. Codigo novo ao lado do atual, depois a troca. O .env passa de uma versao para a outra e a
#    versao anterior fica em backend.anterior para voltar a mao, se preciso.
log "Instalando a versão $RELEASE em $APP"
mkdir -p "$BASE"
rm -rf "$APP.novo"
mkdir -p "$APP.novo"
tar -xzf "$ARCHIVE" -C "$APP.novo" --strip-components=1
rm -f "$ARCHIVE"
if [[ -f "$ENV_FILE" ]]; then
  cp -p "$ENV_FILE" "$APP.novo/.env"
fi
rm -rf "$APP.anterior"
if [[ -d "$APP" ]]; then
  mv "$APP" "$APP.anterior"
fi
mv "$APP.novo" "$APP"

# 3. Configuracao. Na primeira vez cria o .env com uma chave de cifra nova.
NEW_KEY=""
if [[ ! -f "$ENV_FILE" ]]; then
  log "Criando $ENV_FILE"
  NEW_KEY="$(head -c 32 /dev/urandom | base64)"
  (
    umask 077
    cat >"$ENV_FILE" <<EOF
# Criado por deploy/no-servidor.sh em $(date -u +%FT%TZ). As demais opcoes estao em .env.example.
DOMAIN=$DOMAIN_ARG
DATA_ENCRYPTION_KEY=$NEW_KEY
NODE_ENV=production
LOG_LEVEL=info
EOF
  )
elif [[ -n "$DOMAIN_ARG" ]]; then
  CURRENT_DOMAIN="$(sed -n 's/^DOMAIN=//p' "$ENV_FILE" | tail -n 1 | tr -d '\r')"
  if [[ "$CURRENT_DOMAIN" != "$DOMAIN_ARG" ]]; then
    sed -i "s/^DOMAIN=.*/DOMAIN=$DOMAIN_ARG/" "$ENV_FILE"
    echo "Aviso: domínio trocado de '$CURRENT_DOMAIN' para '$DOMAIN_ARG'. Os apps compilados com o" >&2
    echo "endereço antigo deixam de funcionar: compile de novo com o novo endereço." >&2
  fi
fi
chmod 600 "$ENV_FILE"
DOMAIN="$(sed -n 's/^DOMAIN=//p' "$ENV_FILE" | tail -n 1 | tr -d '\r')"
[[ "$DOMAIN" =~ $DOMAIN_PATTERN ]] || fail "DOMAIN inválido em $ENV_FILE: '$DOMAIN'."

# 4. O Caddy so obtem o certificado se o dominio apontar para este servidor.
RESOLVED="$(getent ahostsv4 "$DOMAIN" | awk 'NR == 1 { print $1 }' || true)"
if [[ -z "$RESOLVED" ]]; then
  fail "o domínio $DOMAIN ainda não aponta para nenhum endereço. Crie o registro A no DNS com o IP deste servidor, espere propagar e rode de novo."
fi
if ! hostname -I 2>/dev/null | tr ' ' '\n' | grep -qxF "$RESOLVED"; then
  echo "Aviso: $DOMAIN aponta para $RESOLVED, que não está entre os endereços deste servidor" >&2
  echo "($(hostname -I 2>/dev/null | xargs)). Em provedores com NAT (AWS, Oracle, Google Cloud) isso é" >&2
  echo "normal. Nos demais, corrija o registro A antes que o Caddy esgote as tentativas." >&2
fi

# 5. Firewall: so mexe no ufw se ele ja estiver ativo. O firewall do painel do provedor, se
#    houver, precisa liberar as mesmas portas.
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
  log "Liberando as portas 80 e 443 no ufw"
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
  ufw allow 443/udp >/dev/null
fi

# 6. Conteineres. --pull traz as correcoes mais recentes das imagens base (Node e Caddy).
log "Construindo e subindo os contêineres"
cd "$APP"
docker compose pull --quiet caddy
docker compose build --pull api
docker compose up -d --remove-orphans
docker image prune -f >/dev/null

log "Conferindo a API"
API_OK=""
for _ in $(seq 1 30); do
  if docker compose exec -T api node -e "fetch('http://127.0.0.1:8080/health').then((r) => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" </dev/null >/dev/null 2>&1; then
    API_OK=1
    break
  fi
  sleep 2
done
if [[ -z "$API_OK" ]]; then
  docker compose logs --tail 60 api
  fail "a API não respondeu. Veja os logs acima."
fi

log "Conferindo o HTTPS de https://$DOMAIN (o primeiro certificado leva alguns segundos)"
HTTPS_OK=""
for _ in $(seq 1 40); do
  if curl -fsS --max-time 5 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/health" >/dev/null 2>&1; then
    HTTPS_OK=1
    break
  fi
  sleep 3
done
if [[ -z "$HTTPS_OK" ]]; then
  docker compose logs --tail 40 caddy
  fail "o HTTPS não respondeu. O Caddy precisa que o DNS aponte para este servidor e que as portas 80 e 443 estejam abertas no provedor. Veja os logs acima e rode de novo."
fi

# 7. Backup diario do banco as 3h30 (horario do servidor).
cat >/etc/cron.d/parentalynx-backup <<EOF
# Backup diario do banco do ParentaLynx. Instalado por deploy/no-servidor.sh.
30 3 * * * root bash $APP/deploy/backup.sh >>/var/log/parentalynx-backup.log 2>&1
EOF
chmod 644 /etc/cron.d/parentalynx-backup

if [[ -n "$NEW_KEY" ]]; then
  cat <<EOF

==================================================================================
CHAVE DE CIFRA DO BANCO (DATA_ENCRYPTION_KEY). Ela aparece só desta vez:

    $NEW_KEY

Guarde em um gerenciador de senhas, fora deste servidor. Sem ela, os backups do
banco não podem ser lidos. Uma cópia fica em $ENV_FILE.
==================================================================================
EOF
fi

cat <<EOF

Pronto: https://$DOMAIN está no ar com a versão $RELEASE.
No app, o endereço fica em app/lib/app/config/app_config.dart:
    static const String serverUrl = 'https://$DOMAIN';
EOF
