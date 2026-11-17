import '../../../../core/json/json_reader.dart';

/// Conta do responsavel e sessao (protocolo, secao 2.1).

/// Ajustes da conta que valem para todos os aparelhos.
class GuardianSettings {
  const GuardianSettings({
    this.retentionDays = 90,
    this.syncStaleMinutes = 180,
    this.offlineHours = 24,
    this.lowTimeMinutes = 10,
  });

  factory GuardianSettings.fromJson(JsonMap json) {
    return GuardianSettings(
      retentionDays: json.intOr('retentionDays', fallback: 90),
      syncStaleMinutes: json.intOr('syncStaleMinutes', fallback: 180),
      offlineHours: json.intOr('offlineHours', fallback: 24),
      lowTimeMinutes: json.intOr('lowTimeMinutes', fallback: 10),
    );
  }

  /// Dias que sessoes, eventos, navegacao e alertas ficam guardados (30 a 365).
  final int retentionDays;

  /// Minutos sem sincronizar ate o alerta "sem sincronizacao" (30 a 1440).
  final int syncStaleMinutes;

  /// Horas sem sincronizar ate o alerta "aparelho offline" (6 a 168).
  final int offlineHours;

  /// Minutos restantes que disparam o alerta "pouco tempo" (1 a 60).
  final int lowTimeMinutes;

  GuardianSettings copyWith({
    int? retentionDays,
    int? syncStaleMinutes,
    int? offlineHours,
    int? lowTimeMinutes,
  }) {
    return GuardianSettings(
      retentionDays: retentionDays ?? this.retentionDays,
      syncStaleMinutes: syncStaleMinutes ?? this.syncStaleMinutes,
      offlineHours: offlineHours ?? this.offlineHours,
      lowTimeMinutes: lowTimeMinutes ?? this.lowTimeMinutes,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'retentionDays': retentionDays,
      'syncStaleMinutes': syncStaleMinutes,
      'offlineHours': offlineHours,
      'lowTimeMinutes': lowTimeMinutes,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is GuardianSettings &&
        other.retentionDays == retentionDays &&
        other.syncStaleMinutes == syncStaleMinutes &&
        other.offlineHours == offlineHours &&
        other.lowTimeMinutes == lowTimeMinutes;
  }

  @override
  int get hashCode => Object.hash(retentionDays, syncStaleMinutes, offlineHours, lowTimeMinutes);
}

class GuardianAccount {
  const GuardianAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.settings = const GuardianSettings(),
    this.notificationPrefs = const <String, bool>{},
  });

  factory GuardianAccount.fromJson(JsonMap json) {
    final JsonMap? settings = json.objOrNull('settings');
    final JsonMap? prefs = json.objOrNull('notificationPrefs');
    return GuardianAccount(
      id: json.str('id'),
      email: json.str('email'),
      displayName: json.strOrNull('displayName') ?? '',
      createdAt: json.intOr('createdAt', fallback: 0),
      settings: settings == null ? const GuardianSettings() : GuardianSettings.fromJson(settings),
      notificationPrefs: prefs == null ? const <String, bool>{} : readNotificationPrefs(prefs),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final int createdAt;
  final GuardianSettings settings;

  /// Preferencia por tipo de alerta. Tipo ausente e tratado como ligado.
  final Map<String, bool> notificationPrefs;

  /// Verdadeiro quando o tipo de alerta gera notificacao.
  bool notifies(String alertType) => notificationPrefs[alertType] ?? true;

  GuardianAccount copyWith({
    String? displayName,
    GuardianSettings? settings,
    Map<String, bool>? notificationPrefs,
  }) {
    return GuardianAccount(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      settings: settings ?? this.settings,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
    );
  }
}

/// Le o mapa de preferencias de notificacao, ignorando valores que nao sao booleanos.
Map<String, bool> readNotificationPrefs(JsonMap json) {
  return <String, bool>{
    for (final String key in json.keys)
      if (json.raw[key] is bool) key: json.boolean(key),
  };
}

/// Sessao do responsavel em um aparelho.
class GuardianSessionInfo {
  const GuardianSessionInfo({
    required this.id,
    required this.deviceName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.expiresAt,
    required this.elevatedUntil,
    required this.current,
  });

  factory GuardianSessionInfo.fromJson(JsonMap json) {
    return GuardianSessionInfo(
      id: json.str('id'),
      deviceName: json.strOrNull('deviceName') ?? '',
      createdAt: json.intOr('createdAt', fallback: 0),
      lastSeenAt: json.intOr('lastSeenAt', fallback: 0),
      expiresAt: json.intOr('expiresAt', fallback: 0),
      elevatedUntil: json.intOr('elevatedUntil', fallback: 0),
      current: json.boolOr('current', fallback: false),
    );
  }

  final String id;
  final String deviceName;
  final int createdAt;
  final int lastSeenAt;
  final int expiresAt;

  /// Instante ate o qual as operacoes administrativas estao liberadas sem pedir a senha.
  final int elevatedUntil;

  /// Verdadeiro quando e a sessao deste aparelho.
  final bool current;
}

/// Conta e sessao devolvidas por `GET /v1/guardian/me`.
class GuardianProfile {
  const GuardianProfile({required this.account, required this.session});

  factory GuardianProfile.fromJson(JsonMap json) {
    return GuardianProfile(
      account: GuardianAccount.fromJson(json.obj('guardian')),
      session: GuardianSessionInfo.fromJson(json.obj('session')),
    );
  }

  final GuardianAccount account;
  final GuardianSessionInfo session;
}

/// Resultado de registro, login ou recuperacao: a sessao criada e o seu token.
class AuthResult {
  const AuthResult({
    required this.account,
    required this.session,
    required this.token,
    this.recoveryKey,
  });

  factory AuthResult.fromJson(JsonMap json) {
    final JsonMap session = json.obj('session');
    return AuthResult(
      account: GuardianAccount.fromJson(json.obj('guardian')),
      session: GuardianSessionInfo.fromJson(session),
      token: session.str('token'),
      recoveryKey: json.strOrNull('recoveryKey'),
    );
  }

  final GuardianAccount account;
  final GuardianSessionInfo session;

  /// Token `gs_` da sessao. So vem na criacao.
  final String token;

  /// Chave de recuperacao. Vem no registro e na recuperacao, e e mostrada uma unica vez.
  final String? recoveryKey;
}
