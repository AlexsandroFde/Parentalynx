import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/observable_value.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/i_user_role_repository.dart';
import '../mappers/user_role_mapper.dart';

/// Perfil guardado pelo lado nativo ([AppModeApi]).
///
/// O valor inicial e lido antes do primeiro quadro (bootstrap) e mantido em memoria. Cada
/// troca aceita pelo lado nativo e avisada a quem observa.
class NativeUserRoleRepository implements IUserRoleRepository {
  NativeUserRoleRepository({required this._api, required UserRole initialRole})
    : _role = ObservableValue<UserRole>.seeded(initialRole);

  final AppModeApi _api;
  final ObservableValue<UserRole> _role;

  @override
  UserRole get current => _role.value;

  @override
  Stream<UserRole> watch() => _role.stream;

  @override
  Future<Result<void>> change(UserRole role) async {
    final Result<void> result = await callNative<void>(
      () => _api.setMode(UserRoleMapper.toNative(role)),
      fallback: 'Não foi possível trocar o modo do aplicativo.',
    );
    if (result.isOk) {
      _role.add(role);
    }
    return result;
  }

  /// Le o perfil gravado. Usado uma vez, antes de montar as dependencias.
  static Future<UserRole> readInitial(AppModeApi api) async {
    final Result<AppMode> mode = await callNative<AppMode>(api.getMode);
    return mode.fold(onOk: UserRoleMapper.fromNative, onErr: (_) => UserRole.unset);
  }
}
