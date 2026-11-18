import '../../../../core/platform/native_api.g.dart';
import '../../domain/entities/user_role.dart';

/// Conversao entre o modo da ponte nativa e o perfil do dominio.
abstract final class UserRoleMapper {
  static UserRole fromNative(AppMode mode) {
    return switch (mode) {
      AppMode.unset => UserRole.unset,
      AppMode.guardian => UserRole.guardian,
      AppMode.child => UserRole.child,
    };
  }

  static AppMode toNative(UserRole role) {
    return switch (role) {
      UserRole.unset => AppMode.unset,
      UserRole.guardian => AppMode.guardian,
      UserRole.child => AppMode.child,
    };
  }
}
