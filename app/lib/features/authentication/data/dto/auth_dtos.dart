import '../../../../core/json/json_reader.dart';

// Objetos de transferencia no formato do protocolo (secao 2.1). Espelham o JSON: campos
// opcionais ficam nulos. Os valores padrao e as regras sao aplicados pelo `AuthMapper`.

final class GuardianSettingsDto {
  const GuardianSettingsDto({
    this.retentionDays,
    this.syncStaleMinutes,
    this.offlineHours,
    this.lowTimeMinutes,
  });

  factory GuardianSettingsDto.fromJson(JsonMap json) {
    return GuardianSettingsDto(
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

final class GuardianAccountDto {
  const GuardianAccountDto({
    required this.id,
    required this.email,
    this.displayName,
    this.createdAt,
    this.settings,
    this.notificationPrefs,
  });

  factory GuardianAccountDto.fromJson(JsonMap json) {
    final JsonMap? settings = json.objOrNull('settings');
    final JsonMap? prefs = json.objOrNull('notificationPrefs');
    return GuardianAccountDto(
      id: json.str('id'),
      email: json.str('email'),
      displayName: json.strOrNull('displayName'),
      createdAt: json.intOrNull('createdAt'),
      settings: settings == null ? null : GuardianSettingsDto.fromJson(settings),
      notificationPrefs: prefs == null ? null : readNotificationPrefs(prefs),
    );
  }

  final String id;
  final String email;
  final String? displayName;
  final int? createdAt;
  final GuardianSettingsDto? settings;
  final Map<String, bool>? notificationPrefs;
}

/// Le o mapa de preferencias de notificacao, ignorando valores que nao sao booleanos.
Map<String, bool> readNotificationPrefs(JsonMap json) {
  return <String, bool>{
    for (final String key in json.keys)
      if (json.raw[key] is bool) key: json.boolean(key),
  };
}

final class GuardianSessionDto {
  const GuardianSessionDto({
    required this.id,
    this.deviceName,
    this.createdAt,
    this.lastSeenAt,
    this.expiresAt,
    this.elevatedUntil,
    this.current,
    this.token,
  });

  factory GuardianSessionDto.fromJson(JsonMap json) {
    return GuardianSessionDto(
      id: json.str('id'),
      deviceName: json.strOrNull('deviceName'),
      createdAt: json.intOrNull('createdAt'),
      lastSeenAt: json.intOrNull('lastSeenAt'),
      expiresAt: json.intOrNull('expiresAt'),
      elevatedUntil: json.intOrNull('elevatedUntil'),
      current: json.boolOr('current', fallback: false),
      token: json.strOrNull('token'),
    );
  }

  final String id;
  final String? deviceName;
  final int? createdAt;
  final int? lastSeenAt;
  final int? expiresAt;
  final int? elevatedUntil;
  final bool? current;

  /// Token `gs_`. So vem na criacao da sessao.
  final String? token;
}

/// Resposta de registro, entrada e recuperacao.
final class AuthResponseDto {
  const AuthResponseDto({required this.guardian, required this.session, this.recoveryKey});

  factory AuthResponseDto.fromJson(JsonMap json) {
    return AuthResponseDto(
      guardian: GuardianAccountDto.fromJson(json.obj('guardian')),
      session: GuardianSessionDto.fromJson(json.obj('session')),
      recoveryKey: json.strOrNull('recoveryKey'),
    );
  }

  final GuardianAccountDto guardian;
  final GuardianSessionDto session;
  final String? recoveryKey;
}

/// Resposta de `GET /v1/guardian/me`.
final class ProfileResponseDto {
  const ProfileResponseDto({required this.guardian, required this.session});

  factory ProfileResponseDto.fromJson(JsonMap json) {
    return ProfileResponseDto(
      guardian: GuardianAccountDto.fromJson(json.obj('guardian')),
      session: GuardianSessionDto.fromJson(json.obj('session')),
    );
  }

  final GuardianAccountDto guardian;
  final GuardianSessionDto session;
}
