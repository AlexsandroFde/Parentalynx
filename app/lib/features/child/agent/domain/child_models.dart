/// Modelos do modo crianca. Sao independentes da ponte nativa: a camada de dados converte os
/// tipos gerados pelo Pigeon para estes.
library;

/// Nivel de gerenciamento do aparelho. Define o que o controle consegue garantir.
enum ManagementLevel { standard, deviceAdmin, deviceOwner }

/// Bloqueio geral em vigor no aparelho.
enum ChildLock { none, dailyLimit, schedule, manualLock, tamperLock }

/// Dados deste aparelho enviados no pedido de vinculo (`DeviceInfo` do protocolo).
class DeviceIdentity {
  const DeviceIdentity({
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.androidRelease,
    required this.sdkInt,
    required this.appVersion,
    required this.timezone,
    required this.hardwareId,
  });

  /// Nome amigavel do aparelho.
  final String name;
  final String model;
  final String manufacturer;
  final String androidRelease;
  final int sdkInt;
  final String appVersion;
  final String timezone;
  final String hardwareId;

  DeviceIdentity withName(String value) {
    return DeviceIdentity(
      name: value,
      model: model,
      manufacturer: manufacturer,
      androidRelease: androidRelease,
      sdkInt: sdkInt,
      appVersion: appVersion,
      timezone: timezone,
      hardwareId: hardwareId,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'model': model,
      'manufacturer': manufacturer,
      'androidRelease': androidRelease,
      'sdkInt': sdkInt,
      'appVersion': appVersion,
      'timezone': timezone,
      'hardwareId': hardwareId,
    };
  }
}

/// Estado das permissoes especiais de que o controle depende.
class PermissionFacts {
  const PermissionFacts({
    required this.usageAccess,
    required this.accessibility,
    required this.overlay,
    required this.notifications,
    required this.batteryOptimizationIgnored,
    required this.deviceAdmin,
    required this.deviceOwner,
    required this.exactAlarms,
    required this.restrictedSettingsLikely,
  });

  final bool usageAccess;
  final bool accessibility;
  final bool overlay;
  final bool notifications;
  final bool batteryOptimizationIgnored;
  final bool deviceAdmin;
  final bool deviceOwner;
  final bool exactAlarms;

  /// App instalado por fora da loja em Android 13 ou superior: a acessibilidade pode aparecer
  /// desabilitada ate liberar as "configuracoes restritas".
  final bool restrictedSettingsLikely;

  ManagementLevel get management {
    if (deviceOwner) {
      return ManagementLevel.deviceOwner;
    }
    return deviceAdmin ? ManagementLevel.deviceAdmin : ManagementLevel.standard;
  }
}

/// Retrato do agente de controle parental.
class ChildStatus {
  const ChildStatus({
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
  final List<String> suspensionScopes;

  /// Liberacao concedida pelo responsavel neste aparelho. Zero quando nao ha.
  final int localOverrideUntilMs;
  final PermissionFacts permissions;

  /// Problemas de aplicacao das regras (`accessibility_disabled`, ...).
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
}

/// Tempo de uso de um app hoje.
class AppUsage {
  const AppUsage({
    required this.packageName,
    required this.label,
    required this.ms,
    required this.opens,
  });

  final String packageName;
  final String label;
  final int ms;
  final int opens;
}

/// App que continua disponivel durante um bloqueio geral.
class AllowedApp {
  const AllowedApp({required this.packageName, required this.label, required this.category});

  final String packageName;
  final String label;
  final String category;
}

enum TimeRequestState { pending, approved, denied, expired }

/// Pedido de tempo adicional feito pela crianca.
class TimeRequest {
  const TimeRequest({
    required this.id,
    required this.createdAtMs,
    required this.state,
    required this.delivered,
    this.minutes,
    this.message,
    this.grantedMinutes,
  });

  final String id;
  final int createdAtMs;
  final int? minutes;
  final String? message;
  final TimeRequestState state;
  final int? grantedMinutes;

  /// Verdadeiro quando o pedido ja chegou ao servidor.
  final bool delivered;
}

/// Resultado de uma tentativa de autenticacao do responsavel neste aparelho.
enum AdminAuthStatus {
  /// Autenticado. Operacoes administrativas liberadas por alguns minutos.
  ok,

  /// Senha ou codigo incorreto.
  invalid,

  /// Bloqueado por excesso de tentativas.
  locked,

  /// Sem conexao com o servidor (so para senha).
  offline,

  /// Outro erro.
  error,
}

class AdminAuth {
  const AdminAuth({
    required this.status,
    this.retryAfterSec = 0,
    this.attemptsLeft = -1,
    this.message,
  });

  final AdminAuthStatus status;

  /// Segundos ate poder tentar de novo, quando bloqueado.
  final int retryAfterSec;

  /// Tentativas restantes antes do bloqueio. Negativo quando desconhecido.
  final int attemptsLeft;
  final String? message;
}

/// Resultado de uma sincronizacao pedida pela tela.
class SyncResult {
  const SyncResult({required this.ok, required this.atMs, this.errorCode});

  final bool ok;
  final int atMs;

  /// Codigo de erro do protocolo ou `network`.
  final String? errorCode;
}
