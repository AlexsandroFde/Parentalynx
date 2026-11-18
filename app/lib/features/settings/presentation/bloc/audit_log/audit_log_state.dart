part of 'audit_log_bloc.dart';

/// Registro de alteracoes da conta.
sealed class AuditLogState extends Equatable {
  const AuditLogState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Primeira pagina em andamento.
final class AuditLogLoading extends AuditLogState {
  const AuditLogLoading();
}

/// A primeira pagina nao carregou. A tela oferece tentar de novo.
final class AuditLogError extends AuditLogState {
  const AuditLogError(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

/// Nenhuma alteracao registrada.
final class AuditLogEmpty extends AuditLogState {
  const AuditLogEmpty();
}

final class AuditLogLoaded extends AuditLogState {
  const AuditLogLoaded({
    required this.entries,
    this.nextBefore,
    this.loadingMore = false,
    this.moreFailure,
  });

  final List<AuditEntry> entries;

  /// Cursor da proxima pagina, ou nulo quando nao ha registros mais antigos.
  final int? nextBefore;

  /// Pagina seguinte em andamento.
  final bool loadingMore;

  /// A pagina seguinte nao carregou.
  final AppFailure? moreFailure;

  bool get hasMore => nextBefore != null;

  @override
  List<Object?> get props => <Object?>[entries, nextBefore, loadingMore, moreFailure];
}
