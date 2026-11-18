import '../../../../core/result/result.dart';
import '../entities/audit_entry.dart';
import '../repositories/i_account_management_repository.dart';

/// Uma pagina do registro de alteracoes, do mais novo para o mais antigo.
class LoadAuditLog {
  const LoadAuditLog(this._repository);

  final IAccountManagementRepository _repository;

  /// [before] e o cursor devolvido pela pagina anterior; nulo busca a primeira pagina.
  Future<Result<AuditLogPage>> call({int? before}) => _repository.audit(before: before);
}
