import '../../../../core/result/result.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../entities/audit_entry.dart';

/// Gestao da conta no servidor: perfil, senha, chave de recuperacao, sessoes, auditoria e
/// exclusao (protocolo, secao 2.5).
abstract interface class IAccountManagementRepository {
  /// (E) Altera o nome de exibicao ou os ajustes da conta. Devolve a conta atualizada.
  Future<Result<GuardianAccount>> updateProfile({String? displayName, GuardianSettings? settings});

  /// Troca a senha. As outras sessoes da conta sao encerradas.
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Gera uma nova chave de recuperacao. A anterior deixa de valer.
  Future<Result<String>> regenerateRecoveryKey(String password);

  /// Sessoes abertas da conta (aparelhos de responsaveis).
  Future<Result<List<GuardianSessionInfo>>> listSessions();

  /// (E) Encerra a sessao de outro aparelho.
  Future<Result<void>> revokeSession(String sessionId);

  /// Apaga a conta e todos os dados.
  Future<Result<void>> deleteAccount(String password);

  /// Registro de alteracoes, do mais novo para o mais antigo.
  Future<Result<AuditLogPage>> audit({int? before, int limit = 30});
}
