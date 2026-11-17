// Contrato tipado entre a interface Flutter (Dart) e os modulos nativos Android (Kotlin).
//
// Este arquivo e a unica fonte da ponte. Depois de alterar, gere o codigo com:
//   dart run pigeon --input pigeons/native_api.dart
//
// Regras:
// - Nada de Map<String, Object?> para dados de dominio: cada estrutura tem a sua classe.
// - Chamadas que fazem rede ou disco demorado sao @async.
// - Chamadas administrativas no modo crianca so funcionam com autenticacao do responsavel
//   valida no lado nativo (ver ChildAgentApi.verifyAdminPassword e verifyOfflineCode).

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/native_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/app/src/main/kotlin/com/parentalynx/app/bridge/NativeApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.parentalynx.app.bridge'),
    dartPackageName: 'parentalynx',
  ),
)
/// Modo de funcionamento escolhido na configuracao inicial.
enum AppMode { unset, guardian, child }

/// Nivel de gerenciamento do aparelho no modo crianca.
enum ManagementMode { standard, deviceAdmin, deviceOwner }

/// Bloqueio geral em vigor no aparelho. Espelha `lock.state` do protocolo.
enum LockState { none, dailyLimit, schedule, manualLock, tamperLock }

/// Resultado de uma tentativa de autenticacao do responsavel no aparelho da crianca.
enum AdminAuthOutcome {
  /// Autenticado. Operacoes administrativas liberadas por 5 minutos.
  ok,

  /// Senha ou codigo incorreto.
  invalid,

  /// Bloqueado por excesso de tentativas. Ver `retryAfterSec`.
  locked,

  /// Sem conexao com o servidor (so para senha). Oferecer o codigo de acesso offline.
  offline,

  /// Outro erro (servidor indisponivel, vinculo revogado).
  error,
}

class NativeDeviceInfo {
  NativeDeviceInfo({
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.androidRelease,
    required this.sdkInt,
    required this.appVersion,
    required this.timezone,
    required this.hardwareId,
  });

  /// Nome amigavel do aparelho definido pelo usuario, ou o modelo.
  String name;
  String model;
  String manufacturer;
  String androidRelease;
  int sdkInt;
  String appVersion;

  /// Identificador IANA do fuso do aparelho.
  String timezone;

  /// SHA-256 em hexadecimal do identificador do aparelho para este app.
  String hardwareId;
}

class PermissionSnapshot {
  PermissionSnapshot({
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

  bool usageAccess;
  bool accessibility;
  bool overlay;
  bool notifications;
  bool batteryOptimizationIgnored;
  bool deviceAdmin;
  bool deviceOwner;
  bool exactAlarms;

  /// Android 13 ou superior com app instalado por fora da loja: a acessibilidade pode aparecer
  /// desabilitada ate o usuario liberar "configuracoes restritas" nas informacoes do app.
  bool restrictedSettingsLikely;
}

/// Credenciais entregues pelo servidor quando o responsavel aprova a vinculacao.
class ChildCredentials {
  ChildCredentials({
    required this.serverUrl,
    required this.deviceId,
    required this.deviceToken,
    required this.offlineSecret,
    required this.childName,
    required this.guardianName,
  });

  String serverUrl;
  String deviceId;
  String deviceToken;
  String offlineSecret;
  String childName;
  String guardianName;
}

/// Retrato do agente para a tela da crianca.
class AgentStatus {
  AgentStatus({
    required this.active,
    required this.childName,
    required this.guardianName,
    required this.managementMode,
    required this.lockState,
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
  });

  /// Falso quando o aparelho nao esta vinculado.
  bool active;
  String childName;
  String guardianName;
  ManagementMode managementMode;
  LockState lockState;

  /// Instante previsto de liberacao do bloqueio geral, quando conhecido.
  int? releaseAtMs;

  /// Nome do periodo de bloqueio em vigor, quando o bloqueio e por horario.
  String? activeScheduleLabel;
  bool limitEnabled;

  /// Limite efetivo de hoje, ja com tempo extra. Zero quando o limite esta desligado.
  int limitMs;
  int extraMs;
  int quotaUsedMs;
  int totalUsedMs;

  /// Tempo restante da cota. -1 quando nao ha limite.
  int remainingMs;

  /// Dia da cota corrente (AAAA-MM-DD).
  String day;
  int nextResetAtMs;
  int policyVersion;
  int? lastSyncAtMs;
  bool lastSyncOk;
  String? lastSyncError;

  /// Zero quando nao ha suspensao de regras.
  int suspensionUntilMs;
  List<String> suspensionScopes;

  /// Liberacao local concedida pelo responsavel no proprio aparelho. Zero quando nao ha.
  int localOverrideUntilMs;
  PermissionSnapshot permissions;

  /// Problemas de aplicacao das regras. Mesmos codigos de `enforcement.issues` do protocolo.
  List<String> issues;
  bool clockTrusted;

  /// Hora confiavel do agente (servidor ancorado no relogio monotonico).
  int nowMs;

  /// Proximo bloqueio por horario, quando houver um nas proximas 24 horas.
  int? nextBlockAtMs;
  String? nextBlockLabel;
  int blockedAppsCount;
  int exceptionAppsCount;
  bool managedBrowserEnabled;
}

class UsageEntry {
  UsageEntry({
    required this.packageName,
    required this.label,
    required this.ms,
    required this.opens,
  });

  String packageName;
  String label;
  int ms;
  int opens;
}

class NativeAppInfo {
  NativeAppInfo({
    required this.packageName,
    required this.label,
    required this.category,
    required this.system,
    required this.essential,
  });

  String packageName;
  String label;

  /// Categoria do protocolo (games, social, video, ...).
  String category;
  bool system;
  bool essential;
}

class TimeRequestInfo {
  TimeRequestInfo({
    required this.id,
    required this.createdAtMs,
    required this.status,
    required this.delivered,
  });

  String id;
  int createdAtMs;
  int? minutes;
  String? message;

  /// pending, approved, denied ou expired.
  String status;
  int? grantedMinutes;

  /// Verdadeiro quando o pedido ja chegou ao servidor.
  bool delivered;
}

class AdminAuthResult {
  AdminAuthResult({
    required this.outcome,
    required this.retryAfterSec,
    required this.attemptsLeft,
  });

  AdminAuthOutcome outcome;

  /// Segundos ate poder tentar de novo, quando `locked`. Zero nos demais casos.
  int retryAfterSec;

  /// Tentativas restantes antes do bloqueio, quando conhecido. -1 se desconhecido.
  int attemptsLeft;
  String? message;
}

class SyncOutcome {
  SyncOutcome({required this.ok, required this.atMs});

  bool ok;
  int atMs;

  /// Codigo de erro do protocolo ou `network`, quando `ok` e falso.
  String? errorCode;
}

class BrowserConfig {
  BrowserConfig({
    required this.enabled,
    required this.logHistory,
    required this.safeSearch,
    required this.allowlistMode,
  });

  /// Falso quando o responsavel desligou o navegador gerenciado ou o aparelho nao esta vinculado.
  bool enabled;
  bool logHistory;
  bool safeSearch;

  /// Verdadeiro quando so os dominios autorizados podem ser abertos.
  bool allowlistMode;
}

class UrlDecision {
  UrlDecision({required this.allowed});

  bool allowed;

  /// Motivo do bloqueio: domain_blocked, category, safe_dns ou not_in_allowlist.
  String? reason;

  /// Categoria que causou o bloqueio, quando `reason` e `category`.
  String? category;

  /// Endereco a carregar no lugar do pedido (busca segura), quando diferente.
  String? rewrittenUrl;
}

/// Modo do app e acoes de abertura.
@HostApi()
abstract class AppModeApi {
  AppMode getMode();

  /// Troca o modo. Sair do modo crianca exige autenticacao do responsavel valida no lado
  /// nativo e so e aceito depois de `ChildAgentApi.unlink`.
  void setMode(AppMode mode);

  /// Acao pedida por quem abriu a atividade (notificacao ou tela de bloqueio). Devolve e
  /// consome. Valores: `alerts`, `guardian_area`, `child_home`, `permissions`.
  String? consumeLaunchAction();
}

/// Armazenamento cifrado com chave do Android Keystore.
@HostApi()
abstract class SecureStorageApi {
  String? read(String key);
  void write(String key, String value);
  void delete(String key);
}

/// Informacoes do aparelho, permissoes especiais e atalhos para as telas do sistema.
@HostApi()
abstract class DeviceApi {
  NativeDeviceInfo getDeviceInfo();
  PermissionSnapshot getPermissions();
  void openUsageAccessSettings();
  void openAccessibilitySettings();
  void openOverlaySettings();

  /// Abre o pedido de isencao de otimizacao de bateria para este app.
  void requestIgnoreBatteryOptimizations();
  void openExactAlarmSettings();
  void openNotificationSettings();

  /// Tela de informacoes do app (configuracoes restritas, inicio automatico).
  void openAppDetailsSettings();

  /// Tenta abrir a tela de inicio automatico do fabricante. Falso se nao ha tela conhecida.
  bool openManufacturerAutostartSettings();

  /// Pede a permissao de notificacoes (Android 13 ou superior). Verdadeiro se concedida.
  @async
  bool requestNotificationPermission();

  /// Abre o pedido de ativacao como administrador do dispositivo.
  void requestDeviceAdmin();

  /// Desativa o administrador do dispositivo. Exige autenticacao do responsavel.
  void removeDeviceAdmin();

  /// Remove as restricoes e abre mao do modo Device Owner. Exige autenticacao do responsavel.
  @async
  bool releaseDeviceOwner();
}

/// Agente de controle parental do modo crianca.
@HostApi()
abstract class ChildAgentApi {
  /// Chamado uma unica vez quando a vinculacao e aprovada. Grava as credenciais, aplica a
  /// politica inicial e liga o servico.
  void activate(ChildCredentials credentials, int policyVersion, String policyJson);

  /// Garante que o servico esta rodando (chamado quando o app abre).
  void ensureRunning();
  AgentStatus getStatus();

  /// Politica em vigor no formato do protocolo, ou nulo se nao ha.
  String? getPolicyJson();
  List<UsageEntry> getTodayUsage();

  /// Apps que continuam disponiveis durante um bloqueio geral.
  List<NativeAppInfo> getExceptionApps();

  /// Icone do app em PNG, ou nulo.
  Uint8List? getAppIcon(String packageName);
  @async
  SyncOutcome syncNow();

  /// Registra um pedido de tempo adicional. Devolve o identificador do pedido.
  String submitTimeRequest(int? minutes, String? message);
  List<TimeRequestInfo> getTimeRequests();

  /// Verifica a senha administrativa no servidor.
  @async
  AdminAuthResult verifyAdminPassword(String password);

  /// Verifica localmente o codigo de acesso offline do responsavel.
  AdminAuthResult verifyOfflineCode(String code);

  /// Verdadeiro enquanto a ultima autenticacao do responsavel ainda vale.
  bool isAdminAuthValid();

  /// Libera o uso por alguns minutos. Exige autenticacao do responsavel.
  void grantLocalOverride(int minutes);

  /// Encerra a liberacao local. Nao exige autenticacao.
  void clearLocalOverride();

  /// Desvincula o aparelho. Exige autenticacao do responsavel. Com `password` e conexao, o
  /// servidor revoga o vinculo. Sem conexao, desativa localmente e tenta avisar o servidor.
  @async
  bool unlink(String? password);

  /// Abre o navegador gerenciado, opcionalmente em um endereco.
  void openManagedBrowser(String? url);

  /// Abre um app instalado pelo nome do pacote. Falso se nao foi possivel abrir.
  bool launchApp(String packageName);
}

/// Navegador gerenciado.
@HostApi()
abstract class BrowserApi {
  BrowserConfig getConfig();

  /// Decide se a navegacao de pagina principal pode prosseguir.
  @async
  UrlDecision evaluateUrl(String url);

  /// Registra uma pagina aberta ou bloqueada no historico enviado ao responsavel.
  void recordVisit(String url, String? title, bool blocked, String? reason);

  /// Endereco com que o navegador foi aberto (link tocado em outro app). Devolve e consome.
  String? consumeInitialUrl();
}

/// Recursos nativos usados no modo responsavel.
@HostApi()
abstract class GuardianNativeApi {
  /// Agenda a busca periodica de alertas em segundo plano. O token de sessao e lido do
  /// armazenamento seguro na chave `guardian.session_token`.
  void enableAlertPolling(String serverUrl);
  void disableAlertPolling();

  /// Maior identificador de alerta ja mostrado, para nao notificar duas vezes.
  void setLastSeenAlertId(int id);
  int getLastSeenAlertId();
}

/// Avisos do lado nativo para a interface.
@FlutterApi()
abstract class NativeEventsApi {
  /// A atividade foi reaberta com uma acao (mesmos valores de `consumeLaunchAction`).
  void onLaunchAction(String action);

  /// O navegador gerenciado, ja aberto, recebeu um novo endereco para carregar.
  void onOpenUrl(String url);
}
