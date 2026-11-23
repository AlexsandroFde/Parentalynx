part of 'guardian_entry_bloc.dart';

final class GuardianEntryState extends Equatable {
  const GuardianEntryState({this.roleReset = const ActionIdle()});

  /// Andamento da volta para a escolha de modo.
  final ActionStatus roleReset;

  GuardianEntryState copyWith({ActionStatus? roleReset}) {
    return GuardianEntryState(roleReset: roleReset ?? this.roleReset);
  }

  @override
  List<Object?> get props => <Object?>[roleReset];
}
