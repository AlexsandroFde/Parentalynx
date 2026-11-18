import '../../../../core/json/json_reader.dart';

// Objetos de transferencia da gestao da conta no formato do protocolo (secoes 2.1 e 2.5).
// Espelham o JSON: campos opcionais ficam nulos. Os valores padrao sao aplicados pelo
// `AccountMapper`.

final class AccountSettingsDto {
  const AccountSettingsDto({
    this.retentionDays,
    this.syncStaleMinutes,
    this.offlineHours,
    this.lowTimeMinutes,
  });

  factory AccountSettingsDto.fromJson(JsonMap json) {
    return AccountSettingsDto(
      retentionDays: json.intOrNull('retentionDays'),
      syncStaleMinutes: json.intOrNull('syncStaleMinutes'),
      offlineHours: json.intOrNull('offlineHours'),
      lowTimeMinutes: json.intOrNull('lowTimeMinutes'),
    );
  }

  final int? retentionDays;
  final int? syncStaleMinutes;
  final int? offlineHours;
  final int? lowTimeMinutes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'retentionDays': retentionDays,
      'syncStaleMinutes': syncStaleMinutes,
      'offlineHours': offlineHours,
      'lowTimeMinutes': lowTimeMinutes,
    };
  }
}

/// Conta do responsavel devolvida por `PATCH /v1/guardian/me`.
final class AccountDto {
  const AccountDto({
    required this.id,
    required this.email,
    this.displayName,
    this.createdAt,
    this.settings,
    this.notificationPrefs,
  });

  factory AccountDto.fromJson(JsonMap json) {
    final JsonMap? settings = json.objOrNull('settings');
    final JsonMap? prefs = json.objOrNull('notificationPrefs');
    return AccountDto(
      id: json.str('id'),
      email: json.str('email'),
      displayName: json.strOrNull('displayName'),
      createdAt: json.intOrNull('createdAt'),
      settings: settings == null ? null : AccountSettingsDto.fromJson(settings),
      notificationPrefs: prefs == null
          ? null
          : <String, bool>{
              // Valores que nao sao booleanos sao ignorados.
              for (final String key in prefs.keys)
                if (prefs.raw[key] is bool) key: prefs.boolean(key),
            },
    );
  }

  final String id;
  final String email;
  final String? displayName;
  final int? createdAt;
  final AccountSettingsDto? settings;
  final Map<String, bool>? notificationPrefs;
}

/// Sessao de um aparelho de responsavel em `GET /v1/guardian/sessions`.
final class AccountSessionDto {
  const AccountSessionDto({
    required this.id,
    this.deviceName,
    this.createdAt,
    this.lastSeenAt,
    this.expiresAt,
    this.elevatedUntil,
    this.current,
  });

  factory AccountSessionDto.fromJson(JsonMap json) {
    return AccountSessionDto(
      id: json.str('id'),
      deviceName: json.strOrNull('deviceName'),
      createdAt: json.intOrNull('createdAt'),
      lastSeenAt: json.intOrNull('lastSeenAt'),
      expiresAt: json.intOrNull('expiresAt'),
      elevatedUntil: json.intOrNull('elevatedUntil'),
      current: json.boolOr('current', fallback: false),
    );
  }

  final String id;
  final String? deviceName;
  final int? createdAt;
  final int? lastSeenAt;
  final int? expiresAt;
  final int? elevatedUntil;
  final bool? current;
}

/// Registro de auditoria em `GET /v1/guardian/audit`.
final class AuditEntryDto {
  const AuditEntryDto({
    required this.id,
    this.at,
    this.action,
    this.summary,
    this.deviceName,
    this.targetType,
    this.ip,
  });

  factory AuditEntryDto.fromJson(JsonMap json) {
    return AuditEntryDto(
      id: json.integer('id'),
      at: json.intOrNull('at'),
      action: json.strOrNull('action'),
      summary: json.strOrNull('summary'),
      deviceName: json.strOrNull('deviceName'),
      targetType: json.strOrNull('targetType'),
      ip: json.strOrNull('ip'),
    );
  }

  final int id;
  final int? at;
  final String? action;
  final String? summary;
  final String? deviceName;
  final String? targetType;
  final String? ip;
}

/// Pagina do registro de auditoria.
final class AuditPageDto {
  const AuditPageDto({required this.entries, this.nextBefore});

  factory AuditPageDto.fromJson(JsonMap json) {
    return AuditPageDto(
      entries: json.objList('entries').map(AuditEntryDto.fromJson).toList(),
      nextBefore: json.intOrNull('nextBefore'),
    );
  }

  final List<AuditEntryDto> entries;
  final int? nextBefore;
}
