import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../auth/domain/guardian_account.dart';
import '../domain/account_repository.dart';

class ApiAccountRepository implements AccountRepository {
  const ApiAccountRepository(this._api);

  final ApiClient _api;

  @override
  Future<GuardianAccount> updateProfile({String? displayName, GuardianSettings? settings}) async {
    final JsonMap json = await _api.patch(
      '/v1/guardian/me',
      body: <String, Object?>{'displayName': ?displayName, 'settings': ?settings?.toJson()},
    );
    return GuardianAccount.fromJson(json.obj('guardian'));
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/v1/guardian/password',
      body: <String, Object?>{'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  @override
  Future<String> regenerateRecoveryKey(String password) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/recovery-key',
      body: <String, Object?>{'password': password},
    );
    return json.str('recoveryKey');
  }

  @override
  Future<List<GuardianSessionInfo>> listSessions() async {
    final JsonMap json = await _api.get('/v1/guardian/sessions');
    return json.objList('sessions').map(GuardianSessionInfo.fromJson).toList();
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _api.delete('/v1/guardian/sessions/${Uri.encodeComponent(sessionId)}');
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _api.delete('/v1/guardian/account', body: <String, Object?>{'password': password});
  }

  @override
  Future<AuditPage> audit({int? before, int limit = 30}) async {
    final JsonMap json = await _api.get(
      '/v1/guardian/audit',
      query: <String, String?>{'before': before?.toString(), 'limit': '$limit'},
    );
    return AuditPage.fromJson(json);
  }
}

final Provider<AccountRepository> accountRepositoryProvider = Provider<AccountRepository>(
  (Ref ref) => ApiAccountRepository(ref.watch(apiClientProvider)),
);
