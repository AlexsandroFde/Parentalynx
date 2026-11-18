part of 'guardian_entry_bloc.dart';

final class GuardianEntryState extends Equatable {
  const GuardianEntryState({required this.serverAddress, this.roleReset = const ActionIdle()});

  /// Endereco do servidor em uso, mostrado no rodape.
  final String serverAddress;

  /// Andamento da volta para a escolha de modo.
  final ActionStatus roleReset;

  GuardianEntryState copyWith({String? serverAddress, ActionStatus? roleReset}) {
    return GuardianEntryState(
      serverAddress: serverAddress ?? this.serverAddress,
      roleReset: roleReset ?? this.roleReset,
    );
  }

  @override
  List<Object?> get props => <Object?>[serverAddress, roleReset];
}
