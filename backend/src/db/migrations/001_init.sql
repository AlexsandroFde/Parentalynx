-- Esquema inicial do ParentaLynx.
-- Instantes em milissegundos desde a epoca Unix. Dias no formato YYYY-MM-DD.
-- Colunas com sufixo _enc guardam texto cifrado com AES-256-GCM (ver core/crypto.ts).

CREATE TABLE guardians (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  recovery_key_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  settings TEXT NOT NULL,
  notification_prefs TEXT NOT NULL,
  failed_logins INTEGER NOT NULL DEFAULT 0,
  locked_until INTEGER NOT NULL DEFAULT 0,
  failed_recoveries INTEGER NOT NULL DEFAULT 0,
  recovery_locked_until INTEGER NOT NULL DEFAULT 0
) STRICT;

CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  guardian_id TEXT NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  device_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  elevated_until INTEGER NOT NULL DEFAULT 0,
  revoked_at INTEGER,
  ip TEXT
) STRICT;
CREATE INDEX idx_sessions_guardian ON sessions(guardian_id);

CREATE TABLE pairing_codes (
  id TEXT PRIMARY KEY,
  guardian_id TEXT NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  consumed_at INTEGER,
  invalidated_at INTEGER
) STRICT;
CREATE INDEX idx_pairing_codes_guardian ON pairing_codes(guardian_id);

-- Aparelhos vinculados (ativos ou revogados). Pedidos de vinculo ficam em `links`.
CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  guardian_id TEXT NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('active', 'revoked')),
  child_name TEXT NOT NULL,
  device_name TEXT NOT NULL,
  model TEXT NOT NULL,
  manufacturer TEXT NOT NULL,
  android_release TEXT NOT NULL,
  sdk_int INTEGER NOT NULL,
  app_version TEXT NOT NULL,
  timezone TEXT NOT NULL,
  hardware_id TEXT NOT NULL,
  token_hash TEXT UNIQUE,
  offline_secret_enc TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  approved_at INTEGER NOT NULL,
  revoked_at INTEGER,
  last_sync_at INTEGER,
  last_ip TEXT,
  management_mode TEXT NOT NULL DEFAULT 'standard',
  policy TEXT NOT NULL,
  policy_version INTEGER NOT NULL,
  policy_updated_at INTEGER NOT NULL,
  applied_policy_version INTEGER NOT NULL DEFAULT 0,
  policy_applied_at INTEGER,
  state TEXT,
  inventory_at INTEGER,
  stale_alert_for INTEGER,
  offline_alert_for INTEGER,
  admin_failures INTEGER NOT NULL DEFAULT 0,
  admin_locked_until INTEGER NOT NULL DEFAULT 0
) STRICT;
CREATE INDEX idx_devices_guardian ON devices(guardian_id);
CREATE INDEX idx_devices_hardware ON devices(guardian_id, hardware_id);

-- Pedidos de vinculo. O id do pedido e o que o painel recebe como id do aparelho pendente.
CREATE TABLE links (
  id TEXT PRIMARY KEY,
  guardian_id TEXT NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  code_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected', 'expired', 'delivered')),
  poll_token_hash TEXT NOT NULL UNIQUE,
  confirm_code TEXT NOT NULL,
  device_name TEXT NOT NULL,
  model TEXT NOT NULL,
  manufacturer TEXT NOT NULL,
  android_release TEXT NOT NULL,
  sdk_int INTEGER NOT NULL,
  app_version TEXT NOT NULL,
  timezone TEXT NOT NULL,
  hardware_id TEXT NOT NULL,
  relink_device_id TEXT,
  device_id TEXT,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  resolved_at INTEGER,
  delivered_at INTEGER
) STRICT;
CREATE INDEX idx_links_guardian ON links(guardian_id, status);

-- Tokens de aparelho revogados. Permite responder device_revoked mesmo depois de o aparelho
-- (ou a conta) ter sido apagado. Guarda apenas o hash, sem dado pessoal.
CREATE TABLE revoked_tokens (
  token_hash TEXT PRIMARY KEY,
  revoked_at INTEGER NOT NULL
) STRICT;

CREATE TABLE apps (
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  package TEXT NOT NULL,
  label TEXT NOT NULL,
  category TEXT NOT NULL,
  is_system INTEGER NOT NULL,
  launchable INTEGER NOT NULL,
  essential INTEGER NOT NULL,
  version_name TEXT,
  installed_at INTEGER,
  updated_at INTEGER,
  icon_hash TEXT,
  icon_stored_hash TEXT,
  icon BLOB,
  removed_at INTEGER,
  seen_at INTEGER NOT NULL,
  PRIMARY KEY (device_id, package)
) STRICT;

CREATE TABLE usage_day (
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  day TEXT NOT NULL,
  quota_ms INTEGER NOT NULL DEFAULT 0,
  total_ms INTEGER NOT NULL DEFAULT 0,
  limit_ms INTEGER,
  extra_ms INTEGER NOT NULL DEFAULT 0,
  limit_reached_at INTEGER,
  first_use_at INTEGER,
  last_use_at INTEGER,
  hourly TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (device_id, day)
) STRICT, WITHOUT ROWID;

CREATE TABLE usage_app (
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  day TEXT NOT NULL,
  package TEXT NOT NULL,
  ms INTEGER NOT NULL DEFAULT 0,
  opens INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (device_id, day, package)
) STRICT, WITHOUT ROWID;

CREATE TABLE usage_sessions (
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  client_id TEXT NOT NULL,
  package TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  day TEXT NOT NULL,
  tz_offset_min INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (device_id, client_id)
) STRICT, WITHOUT ROWID;
CREATE INDEX idx_usage_sessions_day ON usage_sessions(device_id, day, start_ms);
CREATE INDEX idx_usage_sessions_created ON usage_sessions(created_at);

CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  client_id TEXT NOT NULL,
  type TEXT NOT NULL,
  ts INTEGER NOT NULL,
  day TEXT NOT NULL,
  package TEXT,
  data_enc TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE (device_id, client_id)
) STRICT;
CREATE INDEX idx_events_device_day ON events(device_id, day, type);
CREATE INDEX idx_events_created ON events(created_at);

CREATE TABLE browsing (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  client_id TEXT NOT NULL,
  ts INTEGER NOT NULL,
  day TEXT NOT NULL,
  url_enc TEXT NOT NULL,
  domain TEXT NOT NULL,
  title_enc TEXT,
  blocked INTEGER NOT NULL,
  reason TEXT,
  created_at INTEGER NOT NULL,
  UNIQUE (device_id, client_id)
) STRICT;
CREATE INDEX idx_browsing_device_day ON browsing(device_id, day);
CREATE INDEX idx_browsing_created ON browsing(created_at);

-- O id e o identificador do evento time_request gerado no aparelho.
CREATE TABLE time_requests (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  minutes INTEGER,
  message_enc TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'denied', 'expired')),
  granted_minutes INTEGER,
  resolved_at INTEGER,
  resolved_by_session TEXT
) STRICT;
CREATE INDEX idx_time_requests_device ON time_requests(device_id, created_at);

-- device_id nao e chave estrangeira: um alerta de vinculo pendente aponta para o id do pedido.
-- O texto e os dados do alerta podem repetir conteudo de eventos (por exemplo a mensagem de um
-- pedido de tempo), por isso tambem sao cifrados.
CREATE TABLE alerts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guardian_id TEXT NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  device_id TEXT,
  child_name TEXT,
  type TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  read_at INTEGER,
  notify INTEGER NOT NULL,
  title TEXT NOT NULL,
  body_enc TEXT NOT NULL,
  data_enc TEXT NOT NULL,
  dedupe_key TEXT,
  origin_session_id TEXT
) STRICT;
CREATE INDEX idx_alerts_guardian ON alerts(guardian_id, id);
CREATE INDEX idx_alerts_dedupe ON alerts(device_id, type, dedupe_key, created_at);

CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guardian_id TEXT NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  at INTEGER NOT NULL,
  action TEXT NOT NULL,
  session_id TEXT,
  session_device_name TEXT,
  target_type TEXT,
  target_id TEXT,
  summary TEXT NOT NULL,
  ip TEXT
) STRICT;
CREATE INDEX idx_audit_guardian ON audit_log(guardian_id, id);
