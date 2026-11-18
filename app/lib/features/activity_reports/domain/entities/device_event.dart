import 'package:equatable/equatable.dart';

/// Detalhes de um evento do aparelho (protocolo, secao 5.3, campo `data`).
///
/// Cada tipo de evento usa alguns destes campos; os demais ficam nulos.
final class EventDetails extends Equatable {
  const EventDetails({
    this.reason,
    this.quotaUsedMs,
    this.remainingMs,
    this.releaseAt,
    this.version,
    this.error,
    this.issue,
    this.permission,
    this.granted,
    this.minutes,
    this.message,
    this.kind,
  });

  static const EventDetails none = EventDetails();

  /// Motivo de um bloqueio (`daily_limit`, `app_blocked`...).
  final String? reason;
  final int? quotaUsedMs;
  final int? remainingMs;
  final int? releaseAt;

  /// Versao da politica aplicada.
  final int? version;
  final String? error;
  final String? issue;

  /// Permissao alterada (`accessibility`, `usageAccess`...).
  final String? permission;
  final bool? granted;
  final int? minutes;
  final String? message;

  /// Tipo da mudanca de relogio (`timezone` ou hora).
  final String? kind;

  @override
  List<Object?> get props => <Object?>[
    reason,
    quotaUsedMs,
    remainingMs,
    releaseAt,
    version,
    error,
    issue,
    permission,
    granted,
    minutes,
    message,
    kind,
  ];
}

/// Evento registrado pelo aparelho (bloqueios, limites, permissoes, seguranca).
final class DeviceEvent extends Equatable {
  const DeviceEvent({
    required this.id,
    required this.type,
    required this.ts,
    this.details = EventDetails.none,
    this.package,
    this.label,
  });

  final int id;

  /// Tipo do protocolo (`blocked_attempt`, `limit_reached`...).
  final String type;
  final int ts;
  final String? package;
  final String? label;
  final EventDetails details;

  /// Nome do app do evento, ou o pacote quando o servidor nao conhece o nome.
  String get appName => label ?? package ?? 'app';

  @override
  List<Object?> get props => <Object?>[id, type, ts, package, label, details];
}
