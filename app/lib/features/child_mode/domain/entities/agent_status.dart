import 'package:equatable/equatable.dart';

import '../../../device_policy/domain/entities/policy.dart';
import 'child_lock.dart';
import 'management_level.dart';
import 'permission_facts.dart';

/// Retrato do agente de controle parental deste aparelho.
///
/// O agente nativo aplica as regras com ou sem a interface aberta. Este retrato so mostra o
/// que ele esta fazendo: o tempo restante vem pronto a cada consulta, sem relogio paralelo no
/// Dart.
final class AgentStatus extends Equatable {
  const AgentStatus({
    required this.active,
    required this.childName,
    required this.guardianName,
    required this.management,
    required this.lock,
    required this.limitEnabled,
    required this.limitMs,
    required this.extraMs,
    required this.quotaUsedMs,
    required this.totalUsedMs,
    required this.remainingMs,
    required this.day,
    required this.nextResetAtMs,
    required this.policyVersion,
    required this.lastSyncOk,
    required this.suspensionUntilMs,
    required this.suspensionScopes,
    required this.localOverrideUntilMs,
    required this.permissions,
    required this.issues,
    required this.clockTrusted,
    required this.nowMs,
    required this.blockedAppsCount,
    required this.exceptionAppsCount,
    required this.managedBrowserEnabled,
    this.releaseAtMs,
    this.activeScheduleLabel,
    this.lastSyncAtMs,
    this.lastSyncError,
    this.nextBlockAtMs,
    this.nextBlockLabel,
  });

  /// Falso quando o aparelho nao esta vinculado.
  final bool active;
  final String childName;
  final String guardianName;
  final ManagementLevel management;
  final ChildLock lock;

  /// Instante previsto de liberacao do bloqueio geral, quando conhecido.
  final int? releaseAtMs;

  /// Nome do periodo de bloqueio em vigor, quando o bloqueio e por horario.
  final String? activeScheduleLabel;
  final bool limitEnabled;

  /// Limite efetivo de hoje, ja com tempo extra. Zero quando o limite esta desligado.
  final int limitMs;
  final int extraMs;
  final int quotaUsedMs;
  final int totalUsedMs;

  /// Tempo restante da cota. Negativo quando nao ha limite.
  final int remainingMs;
  final String day;
  final int nextResetAtMs;
  final int policyVersion;
  final int? lastSyncAtMs;
  final bool lastSyncOk;
  final String? lastSyncError;

  /// Zero quando nao ha suspensao de regras.
  final int suspensionUntilMs;
  final List<SuspensionScope> suspensionScopes;

  /// Liberacao concedida pelo responsavel neste aparelho. Zero quando nao ha.
  final int localOverrideUntilMs;
  final PermissionFacts permissions;

  /// Problemas de aplicacao das regras (por exemplo, acessibilidade desligada), pelos codigos
  /// do protocolo.
  final List<String> issues;
  final bool clockTrusted;

  /// Hora confiavel do agente.
  final int nowMs;
  final int? nextBlockAtMs;
  final String? nextBlockLabel;
  final int blockedAppsCount;
  final int exceptionAppsCount;
  final bool managedBrowserEnabled;

  bool get localOverrideActive => localOverrideUntilMs > nowMs;

  bool get suspensionActive => suspensionUntilMs > nowMs && suspensionScopes.isNotEmpty;

  /// Verdadeiro quando ha um bloqueio geral valendo agora. Uma liberacao local do responsavel
  /// tem prioridade sobre o bloqueio.
  bool get isLocked => lock != ChildLock.none && !localOverrideActive;

  /// Verdadeiro quando ha uma cota de tempo valendo agora.
  bool get hasQuota => limitEnabled && remainingMs >= 0;

  /// Fracao da cota ja usada, de 0 a 1.
  double get usedFraction {
    if (!limitEnabled) {
      return 0;
    }
    if (limitMs <= 0) {
      return 1;
    }
    return (quotaUsedMs / limitMs).clamp(0.0, 1.0);
  }

  /// Verdadeiro quando o controle precisa de atencao (permissao desligada, relogio).
  bool get needsAttention => issues.isNotEmpty || !clockTrusted;

  /// Hora do agente, para os textos relativos nao dependerem do relogio do aparelho.
  DateTime get now => DateTime.fromMillisecondsSinceEpoch(nowMs);

  @override
  List<Object?> get props => <Object?>[
    active,
    childName,
    guardianName,
    management,
    lock,
    releaseAtMs,
    activeScheduleLabel,
    limitEnabled,
    limitMs,
    extraMs,
    quotaUsedMs,
    totalUsedMs,
    remainingMs,
    day,
    nextResetAtMs,
    policyVersion,
    lastSyncAtMs,
    lastSyncOk,
    lastSyncError,
    suspensionUntilMs,
    suspensionScopes,
    localOverrideUntilMs,
    permissions,
    issues,
    clockTrusted,
    nowMs,
    nextBlockAtMs,
    nextBlockLabel,
    blockedAppsCount,
    exceptionAppsCount,
    managedBrowserEnabled,
  ];
}
