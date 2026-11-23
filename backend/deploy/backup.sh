#!/usr/bin/env bash
# Backup consistente do banco, com a API no ar. Roda no VPS pelo cron que no-servidor.sh
# instala (todo dia as 3h30, horario do servidor). Tambem pode ser rodado a mao, como root.
#
# Guarda os arquivos comprimidos em $PLX_DIR/backups e apaga os com mais de KEEP_DAYS dias.
# Eles ficam no mesmo servidor: copie a pasta para fora de tempos em tempos
# (docs/08-servidor-vps.md, secao "Backups").
set -euo pipefail

PLX_DIR="${PLX_DIR:-/opt/parentalynx}"
KEEP_DAYS="${KEEP_DAYS:-14}"
DEST="$PLX_DIR/backups"
NAME="parentalynx-$(date +%F-%H%M%S).db"

cd "$PLX_DIR/backend"
mkdir -p "$DEST"
chmod 700 "$DEST"

# VACUUM INTO gera uma copia consistente mesmo com a API gravando (o banco usa WAL).
docker compose exec -T -e BACKUP_FILE="/data/$NAME" api node -e '
  const { DatabaseSync } = require("node:sqlite");
  const db = new DatabaseSync(process.env.DATABASE_PATH);
  db.prepare("VACUUM INTO ?").run(process.env.BACKUP_FILE);
  db.close();
' </dev/null
docker compose cp "api:/data/$NAME" "$DEST/$NAME"
docker compose exec -T api rm -f "/data/$NAME" </dev/null
gzip -f "$DEST/$NAME"
chmod 600 "$DEST/$NAME.gz"
find "$DEST" -name 'parentalynx-*.db.gz' -mtime +"$KEEP_DAYS" -delete

echo "$(date -u +%FT%TZ) backup gravado em $DEST/$NAME.gz"
