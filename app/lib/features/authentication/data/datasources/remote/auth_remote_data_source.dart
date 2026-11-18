import '../../../../../core/json/json_reader.dart';
import '../../../../../core/network/api_client.dart';
import '../../dto/auth_dtos.dart';

/// Rotas de conta da API (protocolo, secoes 2.2, 2.4 e 2.5). Lanca `AppFailure` em erro; o
/// repositorio converte em `Result`.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AuthResponseDto> register({
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
    return AuthResponseDto.fromJson(json);
  }

  Future<AuthResponseDto> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final JsonMap json = await _api.post(
      '/v1/auth/login',
      auth: ApiAuth.none,
      body: <String, Object?>{'email': email, 'password': password, 'deviceName': deviceName},
    );
    return AuthResponseDto.fromJson(json);
  }

  Future<AuthResponseDto> recover({
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
    return AuthResponseDto.fromJson(json);
  }

  Future<void> logout() async {
    await _api.post('/v1/auth/logout');
  }

  Future<ProfileResponseDto> me() async {
    return ProfileResponseDto.fromJson(await _api.get('/v1/guardian/me'));
  }

  /// Devolve o instante ate o qual a sessao fica elevada.
  Future<int> elevate(String password) async {
    final JsonMap json = await _api.post(
      '/v1/guardian/session/elevate',
      body: <String, Object?>{'password': password},
    );
    return json.integer('elevatedUntil');
  }
}
