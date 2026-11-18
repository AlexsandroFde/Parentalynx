import 'package:equatable/equatable.dart';

/// Registro de auditoria administrativa (protocolo, secao 2.5).
final class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.summary,
    this.deviceName,
    this.targetType,
    this.ip,
  });

  final int id;
  final int at;

  /// Codigo da acao, por exemplo `policy.update` ou `auth.login`.
  final String action;

  /// Descricao pronta em portugues.
  final String summary;

  /// Aparelho do responsavel que fez a alteracao.
  final String? deviceName;
  final String? targetType;
  final String? ip;

  /// Texto para mostrar: a descricao, ou o codigo da acao quando nao ha descricao.
  String get title => summary.isEmpty ? action : summary;

  @override
  List<Object?> get props => <Object?>[id, at, action, summary, deviceName, targetType, ip];
}

/// Pagina do registro de auditoria.
final class AuditLogPage extends Equatable {
  const AuditLogPage({required this.entries, this.nextBefore});

  final List<AuditEntry> entries;

  /// Cursor da pagina seguinte, ou nulo quando nao ha mais registros.
  final int? nextBefore;

  /// Ha registros mais antigos para buscar.
  bool get hasMore => nextBefore != null && entries.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[entries, nextBefore];
}
