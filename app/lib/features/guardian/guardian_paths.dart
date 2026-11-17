/// Caminhos da area do responsavel. Todos comecam com [root].
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
}
