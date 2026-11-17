import '../guardian_paths.dart';

/// Caminhos das paginas de regras, todas abaixo da aba Regras.
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
