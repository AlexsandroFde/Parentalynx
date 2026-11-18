import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/account_dtos.dart';

/// Rotas de gestao da conta do responsavel (protocolo, secoes 2.1 e 2.5). Lanca `AppFailure`
/// em erro.
class AccountRemoteDataSource {
  const AccountRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AccountDto> updateProfile({String? displayName, AccountSettingsDto? settings}) async {
    final JsonMap json = await _api.patch(
      '/v1/guardian/me',
      body: <String, Object?>{'displayName': ?displayName, 'settings': ?settings?.toJson()},
    );
    return AccountDto.fromJson(json.obj('guardian'));
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return _api.post(
      '/v1/guardian/password',
      body: <String, Object?>{'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<String> regenerateRecoveryKey(String password) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/recovery-key',
      body: <String, Object?>{'password': password},
    );
    return json.str('recoveryKey');
  }

  Future<List<AccountSessionDto>> listSessions() async {
    final JsonMap json = await _api.get('/v1/guardian/sessions');
    return json.objList('sessions').map(AccountSessionDto.fromJson).toList();
  }

  Future<void> revokeSession(String sessionId) {
    return _api.delete('/v1/guardian/sessions/${Uri.encodeComponent(sessionId)}');
  }

  Future<void> deleteAccount(String password) {
    return _api.delete('/v1/guardian/account', body: <String, Object?>{'password': password});
  }

  Future<AuditPageDto> audit({int? before, required int limit}) async {
    final JsonMap json = await _api.get(
      '/v1/guardian/audit',
      query: <String, String?>{'before': before?.toString(), 'limit': '$limit'},
    );
    return AuditPageDto.fromJson(json);
  }
}
