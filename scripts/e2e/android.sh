#!/usr/bin/env bash
# Funcoes de apoio para os roteiros de validacao em emulador ou aparelho, via adb.
#
# Uso: source scripts/e2e/android.sh   (depois chame as funcoes)
#
# Variaveis:
#   ADB   caminho do adb (padrao: o do Android SDK)
#   PKG   pacote do app (padrao: com.parentalynx.app)
#
# Observacao: `ui_dump` usa o uiautomator, que suspende os outros servicos de acessibilidade
# enquanto coleta a tela. Nao use as funcoes ui_* no meio de um teste de bloqueio: prefira
# `top_activity`, `logcat_since` e as consultas ao servidor.

ADB="${ADB:-$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe}"
PKG="${PKG:-com.parentalynx.app}"

# Alvo fixo: por padrao so o emulador. Com um celular fisico conectado ao mesmo tempo, isto
# garante que nenhum comando destes roteiros caia nele por engano. Para testar em um aparelho
# fisico, defina ANDROID_SERIAL com o numero de serie mostrado por `adb devices`.
export ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
A11Y="$PKG/$PKG.service.ParentalAccessibilityService"

adb_() { "$ADB" "$@"; }

# Espera o sistema terminar de iniciar.
wait_boot() {
  adb_ wait-for-device
  local i
  for i in $(seq 1 180); do
    if [ "$(adb_ shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
      echo "boot concluido em ~$((i * 2)) s"
      return 0
    fi
    sleep 2
  done
  echo "o emulador nao terminou de iniciar" >&2
  return 1
}

# Atividade em primeiro plano, no formato pacote/classe.
top_activity() {
  adb_ shell dumpsys activity activities 2>/dev/null | tr -d '\r' |
    grep -m1 -E "topResumedActivity|mResumedActivity" | sed -E 's/.* ([^ ]+\/[^ ]+) .*/\1/'
}

# Textos visiveis na tela (texto e descricao de acessibilidade), um por linha.
ui_dump() {
  adb_ exec-out uiautomator dump /dev/tty 2>/dev/null | tr -d '\r' | sed 's/UI hierchary dumped to: \/dev\/tty//'
}

# Um elemento da tela por linha.
ui_nodes() { ui_dump | sed 's/>/>\n/g'; }

ui_texts() {
  ui_dump | grep -oE '(text|content-desc)="[^"]+"' | sed -E 's/^(text|content-desc)="//; s/"$//' | awk 'length > 0' | uniq
}

# Centro do primeiro elemento cujo texto ou descricao contem o trecho informado.
ui_center() {
  local needle="$1"
  # O dump vem em uma linha so: quebra em um elemento por linha antes de procurar.
  ui_nodes | grep -F "$needle" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1 |
    sed -E 's/bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' |
    awk '{ printf "%d %d", ($1 + $3) / 2, ($2 + $4) / 2 }'
}

# Toca no elemento que contem o texto. Falha se nao encontrar.
tap_text() {
  local needle="$1" center
  center="$(ui_center "$needle")"
  if [ -z "$center" ]; then
    echo "nao achei na tela: $needle" >&2
    return 1
  fi
  # shellcheck disable=SC2086
  adb_ shell input tap $center
  echo "toque em \"$needle\" ($center)"
}

# Espera um texto aparecer na tela (padrao: 30 s).
wait_text() {
  local needle="$1" timeout="${2:-30}" i
  for i in $(seq 1 "$timeout"); do
    if ui_dump | grep -qF "$needle"; then
      echo "na tela: $needle"
      return 0
    fi
    sleep 1
  done
  echo "nao apareceu em $timeout s: $needle" >&2
  return 1
}

# Digita texto no campo com foco (sem espacos nem acentos).
type_text() { adb_ shell input text "$1"; }

key() { adb_ shell input keyevent "$1"; }

# Concede pelo adb as permissoes especiais do modo crianca (equivale ao assistente).
grant_child_permissions() {
  adb_ shell appops set "$PKG" GET_USAGE_STATS allow
  adb_ shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS 2>/dev/null
  adb_ shell cmd deviceidle whitelist "+$PKG" >/dev/null
  adb_ shell appops set "$PKG" SYSTEM_ALERT_WINDOW allow
  enable_accessibility
}

enable_accessibility() {
  adb_ shell settings put secure enabled_accessibility_services "$A11Y"
  adb_ shell settings put secure accessibility_enabled 1
}

disable_accessibility() {
  adb_ shell settings delete secure enabled_accessibility_services >/dev/null
  adb_ shell settings put secure accessibility_enabled 0
}

# Abre um app pelo intent de launcher do pacote.
launch_pkg() {
  adb_ shell monkey -p "$1" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

home() { key KEYCODE_HOME; }

# Linhas de log do agente desde o marcador de tempo informado (formato do logcat -T).
plx_log() {
  adb_ logcat -d -v time 2>/dev/null | tr -d '\r' | grep -E " [VDIWE]/PLX" | tail -"${1:-40}"
}

clear_log() { adb_ logcat -c; }

# Verdadeiro se o servico em primeiro plano do agente esta ativo.
service_state() {
  adb_ shell dumpsys activity services "$PKG" 2>/dev/null | tr -d '\r' |
    grep -E "ServiceRecord|isForeground|foregroundServiceType" | head -8
}

# Pacotes suspensos pelo sistema (modo Device Owner).
suspended_packages() {
  adb_ shell dumpsys package 2>/dev/null | tr -d '\r' |
    awk '/^  Package \[/ { pkg = $2 } /suspended=true/ { print pkg }' | tr -d '[]' | sort -u
}

screenshot() {
  adb_ exec-out screencap -p > "$1"
  echo "captura salva em $1"
}

# Toca no botao (elemento com a classe Button) cujo rotulo contem o texto. Util quando o mesmo
# texto aparece tambem como titulo da tela.
tap_button() {
  local needle="$1" center
  center="$(ui_nodes | grep -F 'class="android.widget.Button"' | grep -F "$needle" |
    grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1 |
    sed -E 's/bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' |
    awk '{ printf "%d %d", ($1 + $3) / 2, ($2 + $4) / 2 }')"
  if [ -z "$center" ]; then
    echo "nao achei o botao: $needle" >&2
    return 1
  fi
  # shellcheck disable=SC2086
  adb_ shell input tap $center
  echo "toque no botao \"$needle\" ($center)"
}
