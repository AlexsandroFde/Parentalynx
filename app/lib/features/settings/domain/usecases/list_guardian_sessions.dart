import '../../../../core/result/result.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../repositories/i_account_management_repository.dart';

/// Sessoes abertas da conta: os aparelhos de responsaveis com acesso.
class ListGuardianSessions {
  const ListGuardianSessions(this._repository);

  final IAccountManagementRepository _repository;

  Future<Result<List<GuardianSessionInfo>>> call() => _repository.listSessions();
}
