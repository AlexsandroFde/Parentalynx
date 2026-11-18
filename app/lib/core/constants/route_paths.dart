/// Caminhos de navegacao do app.
///
/// Ficam no nucleo porque sao o contrato entre as funcionalidades: uma tela navega para outra
/// pelo caminho, sem importar a funcionalidade de destino. As rotas em si sao declaradas por
/// cada funcionalidade (`features/<nome>/<nome>_routes.dart`) e montadas em `app/router`.
library;

/// Configuracao inicial: boas-vindas e escolha do modo.
abstract final class OnboardingPaths {
  static const String welcome = '/welcome';
}

/// Area do responsavel. Todos os caminhos comecam com [root].
///
/// As abas do painel sao [home], [rules], [reports], [alerts] e [more]. Cada funcionalidade
/// define os seus subcaminhos abaixo da sua aba (por exemplo `/guardian/rules/limit`).
abstract final class GuardianPaths {
  static const String root = '/guardian';

  // Conta e sessao.
  static const String signIn = '/guardian/sign-in';
  static const String register = '/guardian/register';
  static const String login = '/guardian/login';
  static const String recover = '/guardian/recover';
  static const String recoveryKey = '/guardian/recovery-key';
  static const String unlock = '/guardian/unlock';

  // Abas do painel.
  static const String home = '/guardian/home';
  static const String rules = '/guardian/rules';
  static const String reports = '/guardian/reports';
  static const String alerts = '/guardian/alerts';
  static const String more = '/guardian/more';

  // Telas fora das abas.
  static const String pairing = '/guardian/pairing';
  static const String devices = '/guardian/devices';

  /// Detalhe de um aparelho.
  static String device(String deviceId) => '$devices/${Uri.encodeComponent(deviceId)}';

  // Abaixo da aba Alertas.
  static const String notificationPrefs = '$alerts/preferences';
  static const String timeRequests = '$alerts/time-requests';

  // Abaixo da aba Mais.
  static const String account = '$more/account';
  static const String sessions = '$more/sessions';
  static const String security = '$more/security';
  static const String privacy = '$more/privacy';
  static const String audit = '$more/audit';
}

/// Paginas de regras, todas abaixo da aba Regras.
abstract final class RulesPaths {
  static const String limit = '${GuardianPaths.rules}/limit';
  static const String hours = '${GuardianPaths.rules}/hours';
  static const String periods = '${GuardianPaths.rules}/periods';
  static const String apps = '${GuardianPaths.rules}/apps';
  static const String exceptions = '${GuardianPaths.rules}/exceptions';
  static const String web = '${GuardianPaths.rules}/web';
  static const String protection = '${GuardianPaths.rules}/protection';

  /// Lista de apps ja filtrada por uma categoria (codigo do protocolo).
  static String appsInCategory(String categoryCode) => '$apps?category=$categoryCode';
}

/// Paginas de detalhe dos relatorios, abaixo da aba Relatorios.
abstract final class ReportsPaths {
  static const String sessions = '${GuardianPaths.reports}/sessions';
  static const String events = '${GuardianPaths.reports}/events';
  static const String browsing = '${GuardianPaths.reports}/browsing';

  static String sessionsOf(String day) => '$sessions?day=$day';

  static String eventsIn(String from, String to) => '$events?from=$from&to=$to';

  static String browsingIn(String from, String to) => '$browsing?from=$from&to=$to';
}

/// Area da crianca. Todos os caminhos comecam com [root].
abstract final class ChildPaths {
  /// Tela de entrada, mostrada enquanto se descobre se o aparelho esta vinculado.
  static const String root = '/child';

  /// Vinculacao: codigo e espera da aprovacao.
  static const String link = '/child/link';

  /// Prefixo das telas da configuracao inicial, logo depois da vinculacao.
  static const String setupPrefix = '/child/setup/';
  static const String setupTransparency = '/child/setup/transparency';
  static const String setupPermissions = '/child/setup/permissions';

  /// Tela inicial da crianca.
  static const String home = '/child/home';

  /// O que o app controla, o que registra e o que nao ve.
  static const String about = '/child/about';

  /// Permissoes do controle, fora da configuracao inicial.
  static const String permissions = '/child/permissions';

  /// Area do responsavel neste aparelho.
  static const String guardianArea = '/child/guardian';
}
