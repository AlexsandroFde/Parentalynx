part of 'user_role_bloc.dart';

/// Perfil em vigor neste aparelho.
final class UserRoleState extends Equatable {
  const UserRoleState(this.role);

  final UserRole role;

  @override
  List<Object?> get props => <Object?>[role];
}
