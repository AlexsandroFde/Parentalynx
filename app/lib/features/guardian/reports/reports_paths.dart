import '../guardian_paths.dart';

/// Caminhos das paginas de detalhe dos relatorios, abaixo da aba Relatorios.
abstract final class ReportsPaths {
  static const String sessions = '${GuardianPaths.reports}/sessions';
  static const String events = '${GuardianPaths.reports}/events';
  static const String browsing = '${GuardianPaths.reports}/browsing';

  static String sessionsOf(String day) => '$sessions?day=$day';

  static String eventsIn(String from, String to) => '$events?from=$from&to=$to';

  static String browsingIn(String from, String to) => '$browsing?from=$from&to=$to';
}
