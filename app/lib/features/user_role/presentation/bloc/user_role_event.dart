part of 'user_role_bloc.dart';

sealed class UserRoleEvent extends Equatable {
  const UserRoleEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Passa a acompanhar as trocas de perfil. Disparado uma vez, na criacao do BLoC.
final class UserRoleSubscriptionRequested extends UserRoleEvent {
  const UserRoleSubscriptionRequested();
}
