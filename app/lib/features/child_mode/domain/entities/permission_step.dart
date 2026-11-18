import 'package:equatable/equatable.dart';

/// Permissoes e ajustes de que o controle parental depende neste aparelho.
enum PermissionKind {
  usageAccess,
  accessibility,
  notifications,
  batteryOptimization,
  overlay,
  exactAlarms,
  deviceAdmin,
  autostart,
}

enum PermissionImportance {
  /// Sem ela o controle nao funciona direito.
  required,

  /// Deixa o controle mais confiavel.
  recommended,

  /// Reforco que o responsavel pode escolher.
  optional,
}

final class PermissionStep extends Equatable {
  const PermissionStep({required this.kind, required this.importance, required this.granted});

  final PermissionKind kind;
  final PermissionImportance importance;

  /// Nulo quando o sistema nao informa o estado (inicio automatico do fabricante).
  final bool? granted;

  bool get isPending => granted == false;

  bool get isRequired => importance == PermissionImportance.required;

  @override
  List<Object?> get props => <Object?>[kind, importance, granted];
}

/// O que aconteceu ao tentar abrir a tela de uma permissao.
enum PermissionActionResult {
  /// A tela do sistema foi aberta. O estado e reconsultado quando o app voltar.
  opened,

  /// A permissao foi concedida na hora (dialogo do sistema).
  granted,

  /// Nao ha tela conhecida para este fabricante. Foi aberta a tela de informacoes do app.
  fallbackToAppDetails,
}
