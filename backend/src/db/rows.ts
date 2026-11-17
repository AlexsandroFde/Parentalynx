// Formato das linhas lidas do banco (nomes de coluna em snake_case, como no SQL).

export interface GuardianRow {
  id: string;
  email: string;
  display_name: string;
  password_hash: string;
  recovery_key_hash: string;
  created_at: number;
  settings: string;
  notification_prefs: string;
  failed_logins: number;
  locked_until: number;
  failed_recoveries: number;
  recovery_locked_until: number;
}

export interface SessionRow {
  id: string;
  guardian_id: string;
  token_hash: string;
  device_name: string;
  created_at: number;
  last_seen_at: number;
  expires_at: number;
  elevated_until: number;
  revoked_at: number | null;
  ip: string | null;
}

export interface PairingCodeRow {
  id: string;
  guardian_id: string;
  code_hash: string;
  created_at: number;
  expires_at: number;
  consumed_at: number | null;
  invalidated_at: number | null;
}

export type DeviceStatus = 'active' | 'revoked';
export type ManagementMode = 'standard' | 'device_admin' | 'device_owner';

export interface DeviceRow {
  id: string;
  guardian_id: string;
  status: DeviceStatus;
  child_name: string;
  device_name: string;
  model: string;
  manufacturer: string;
  android_release: string;
  sdk_int: number;
  app_version: string;
  timezone: string;
  hardware_id: string;
  token_hash: string | null;
  offline_secret_enc: string;
  created_at: number;
  approved_at: number;
  revoked_at: number | null;
  last_sync_at: number | null;
  last_ip: string | null;
  management_mode: ManagementMode;
  policy: string;
  policy_version: number;
  policy_updated_at: number;
  applied_policy_version: number;
  policy_applied_at: number | null;
  state: string | null;
  inventory_at: number | null;
  stale_alert_for: number | null;
  offline_alert_for: number | null;
  admin_failures: number;
  admin_locked_until: number;
}

export type LinkStatus = 'pending' | 'approved' | 'rejected' | 'expired' | 'delivered';

export interface LinkRow {
  id: string;
  guardian_id: string;
  code_id: string;
  status: LinkStatus;
  poll_token_hash: string;
  confirm_code: string;
  device_name: string;
  model: string;
  manufacturer: string;
  android_release: string;
  sdk_int: number;
  app_version: string;
  timezone: string;
  hardware_id: string;
  relink_device_id: string | null;
  device_id: string | null;
  created_at: number;
  expires_at: number;
  resolved_at: number | null;
  delivered_at: number | null;
}

export interface AppRow {
  device_id: string;
  package: string;
  label: string;
  category: string;
  is_system: number;
  launchable: number;
  essential: number;
  version_name: string | null;
  installed_at: number | null;
  updated_at: number | null;
  icon_hash: string | null;
  icon_stored_hash: string | null;
  removed_at: number | null;
  seen_at: number;
}

export interface UsageDayRow {
  device_id: string;
  day: string;
  quota_ms: number;
  total_ms: number;
  limit_ms: number | null;
  extra_ms: number;
  limit_reached_at: number | null;
  first_use_at: number | null;
  last_use_at: number | null;
  hourly: string;
  updated_at: number;
}

export interface TimeRequestRow {
  id: string;
  device_id: string;
  created_at: number;
  minutes: number | null;
  message_enc: string | null;
  status: 'pending' | 'approved' | 'denied' | 'expired';
  granted_minutes: number | null;
  resolved_at: number | null;
  resolved_by_session: string | null;
}

export interface AlertRow {
  id: number;
  guardian_id: string;
  device_id: string | null;
  child_name: string | null;
  type: string;
  created_at: number;
  read_at: number | null;
  notify: number;
  title: string;
  body_enc: string;
  data_enc: string;
  dedupe_key: string | null;
  origin_session_id: string | null;
}

export interface AuditRow {
  id: number;
  guardian_id: string;
  at: number;
  action: string;
  session_id: string | null;
  session_device_name: string | null;
  target_type: string | null;
  target_id: string | null;
  summary: string;
  ip: string | null;
}
