import '../../../../core/result/result.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/i_account_management_repository.dart';
import '../datasources/remote/account_remote_data_source.dart';
import '../dto/account_dtos.dart';
import '../mappers/account_mapper.dart';

/// Gestao da conta pela API.
class ApiAccountManagementRepository implements IAccountManagementRepository {
  const ApiAccountManagementRepository(this._remote);

  final AccountRemoteDataSource _remote;

  @override
  Future<Result<GuardianAccount>> updateProfile({String? displayName, GuardianSettings? settings}) {
    return Result.guard(() async {
      final AccountDto account = await _remote.updateProfile(
        displayName: displayName,
        settings: settings == null ? null : AccountMapper.settingsToDto(settings),
      );
      return AccountMapper.account(account);
    });
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return Result.guard(
      () => _remote.changePassword(currentPassword: currentPassword, newPassword: newPassword),
    );
  }

  @override
  Future<Result<String>> regenerateRecoveryKey(String password) {
    return Result.guard(() => _remote.regenerateRecoveryKey(password));
  }

  @override
  Future<Result<List<GuardianSessionInfo>>> listSessions() {
    return Result.guard(() async {
      final List<AccountSessionDto> sessions = await _remote.listSessions();
      return sessions.map(AccountMapper.session).toList();
    });
  }

  @override
  Future<Result<void>> revokeSession(String sessionId) {
    return Result.guard(() => _remote.revokeSession(sessionId));
  }

  @override
  Future<Result<void>> deleteAccount(String password) {
    return Result.guard(() => _remote.deleteAccount(password));
  }

  @override
  Future<Result<AuditLogPage>> audit({int? before, int limit = 30}) {
    return Result.guard(
      () async => AccountMapper.auditPage(await _remote.audit(before: before, limit: limit)),
    );
  }
}
