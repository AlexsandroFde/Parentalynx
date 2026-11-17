import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../domain/auth_repository.dart';
import '../domain/guardian_account.dart';

/// Implementacao de [AuthRepository] sobre a API.
class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthResult> register({
    required String email,
    required String displayName,
    required String password,
    required String deviceName,
  }) async {
    final JsonMap json = await _api.post(
      '/v1/auth/register',
      auth: ApiAuth.none,
      body: <String, Object?>{
        'email': email,
        'displayName': displayName,
        'password': password,
        'deviceName': deviceName,
      },
    );
    return AuthResult.fromJson(json);
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final JsonMap json = await _api.post(
      '/v1/auth/login',
      auth: ApiAuth.none,
      body: <String, Object?>{'email': email, 'password': password, 'deviceName': deviceName},
    );
    return AuthResult.fromJson(json);
  }

  @override
  Future<AuthResult> recover({
    required String email,
    required String recoveryKey,
    required String newPassword,
    required String deviceName,
  }) async {
    final JsonMap json = await _api.post(
      '/v1/auth/recover',
      auth: ApiAuth.none,
      body: <String, Object?>{
        'email': email,
        'recoveryKey': recoveryKey,
        'newPassword': newPassword,
        'deviceName': deviceName,
      },
    );
    return AuthResult.fromJson(json);
  }

  @override
  Future<void> logout() async {
    await _api.post('/v1/auth/logout');
  }

  @override
  Future<GuardianProfile> me() async {
    return GuardianProfile.fromJson(await _api.get('/v1/guardian/me'));
  }

  @override
  Future<int> elevate(String password) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/session/elevate',
      body: <String, Object?>{'password': password},
    );
    return json.integer('elevatedUntil');
  }
}

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
