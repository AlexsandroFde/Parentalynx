import 'package:equatable/equatable.dart';

/// Ajustes da conta que valem para todos os aparelhos.
final class GuardianSettings extends Equatable {
  const GuardianSettings({
    this.retentionDays = 90,
    this.syncStaleMinutes = 180,
    this.offlineHours = 24,
    this.lowTimeMinutes = 10,
  });

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

  @override
  List<Object?> get props => <Object?>[
    retentionDays,
    syncStaleMinutes,
    offlineHours,
    lowTimeMinutes,
  ];
}

/// Conta do responsavel (protocolo, secao 2.1).
final class GuardianAccount extends Equatable {
  const GuardianAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.settings = const GuardianSettings(),
    this.notificationPrefs = const <String, bool>{},
  });

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

  @override
  List<Object?> get props => <Object?>[
    id,
    email,
    displayName,
    createdAt,
    settings,
    notificationPrefs,
  ];
}
