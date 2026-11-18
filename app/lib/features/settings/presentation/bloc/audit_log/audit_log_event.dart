part of 'audit_log_bloc.dart';

sealed class AuditLogEvent extends Equatable {
  const AuditLogEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Carregar a primeira pagina: a tela abriu ou a pessoa pediu para tentar de novo.
final class AuditLogLoadRequested extends AuditLogEvent {
  const AuditLogLoadRequested();
}

/// Carregar os registros mais antigos (ou tentar de novo depois de uma falha).
final class AuditLogMoreRequested extends AuditLogEvent {
  const AuditLogMoreRequested();
}
