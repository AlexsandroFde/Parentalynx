import '../../../../core/result/result.dart';
import '../../domain/entities/guardian_session.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/remote/auth_remote_data_source.dart';
import '../dto/auth_dtos.dart';
import '../mappers/auth_mapper.dart';

/// Implementacao de [IAuthRepository] sobre a API.
class ApiAuthRepository implements IAuthRepository {
  const ApiAuthRepository(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<Result<AuthenticatedSession>> register({
    required String email,
    required String displayName,
    required String password,
    required String deviceName,
  }) {
    return Result.guard(() async {
      final AuthResponseDto dto = await _remote.register(
        email: email,
        displayName: displayName,
        password: password,
        deviceName: deviceName,
      );
      return AuthMapper.authenticated(dto);
    });
  }

  @override
  Future<Result<AuthenticatedSession>> login({
    required String email,
    required String password,
    required String deviceName,
  }) {
    return Result.guard(() async {
      final AuthResponseDto dto = await _remote.login(
        email: email,
        password: password,
        deviceName: deviceName,
      );
      return AuthMapper.authenticated(dto);
    });
  }

  @override
  Future<Result<AuthenticatedSession>> recover({
    required String email,
    required String recoveryKey,
    required String newPassword,
    required String deviceName,
  }) {
    return Result.guard(() async {
      final AuthResponseDto dto = await _remote.recover(
        email: email,
        recoveryKey: recoveryKey,
        newPassword: newPassword,
        deviceName: deviceName,
      );
      return AuthMapper.authenticated(dto);
    });
  }

  @override
  Future<Result<void>> logout() => Result.guard(_remote.logout);

  @override
  Future<Result<GuardianProfile>> fetchProfile() {
    return Result.guard(() async => AuthMapper.profile(await _remote.me()));
  }

  @override
  Future<Result<int>> elevate(String password) => Result.guard(() => _remote.elevate(password));
}
