import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/audit_entry.dart';
import '../../../domain/usecases/load_audit_log.dart';

part 'audit_log_event.dart';
part 'audit_log_state.dart';

/// Registro de alteracoes administrativas da conta, paginado do mais novo para o mais antigo.
class AuditLogBloc extends Bloc<AuditLogEvent, AuditLogState> {
  AuditLogBloc({required this._loadAuditLog}) : super(const AuditLogLoading()) {
    on<AuditLogLoadRequested>(_onLoadRequested, transformer: restartable());
    on<AuditLogMoreRequested>(_onMoreRequested, transformer: droppable());
  }

  final LoadAuditLog _loadAuditLog;

  Future<void> _onLoadRequested(AuditLogLoadRequested event, Emitter<AuditLogState> emit) async {
    emit(const AuditLogLoading());
    final Result<AuditLogPage> result = await _loadAuditLog();
    switch (result) {
      case Ok<AuditLogPage>(:final AuditLogPage value):
        emit(
          value.entries.isEmpty
              ? const AuditLogEmpty()
              : AuditLogLoaded(entries: value.entries, nextBefore: _cursorOf(value)),
        );
      case Err<AuditLogPage>(:final AppFailure failure):
        emit(AuditLogError(failure));
    }
  }

  Future<void> _onMoreRequested(AuditLogMoreRequested event, Emitter<AuditLogState> emit) async {
    final AuditLogState current = state;
    if (current is! AuditLogLoaded || current.loadingMore || !current.hasMore) {
      return;
    }
    emit(
      AuditLogLoaded(entries: current.entries, nextBefore: current.nextBefore, loadingMore: true),
    );
    final Result<AuditLogPage> result = await _loadAuditLog(before: current.nextBefore);
    switch (result) {
      case Ok<AuditLogPage>(:final AuditLogPage value):
        emit(
          AuditLogLoaded(
            entries: <AuditEntry>[...current.entries, ...value.entries],
            nextBefore: _cursorOf(value),
          ),
        );
      case Err<AuditLogPage>(:final AppFailure failure):
        emit(
          AuditLogLoaded(
            entries: current.entries,
            nextBefore: current.nextBefore,
            moreFailure: failure,
          ),
        );
    }
  }

  /// Cursor da pagina seguinte, so quando ainda ha registros para buscar.
  static int? _cursorOf(AuditLogPage page) => page.hasMore ? page.nextBefore : null;
}
