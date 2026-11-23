part of 'guardian_entry_bloc.dart';

sealed class GuardianEntryEvent extends Equatable {
  const GuardianEntryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A pessoa quer voltar para a escolha de modo do aparelho.
final class GuardianEntryRoleResetRequested extends GuardianEntryEvent {
  const GuardianEntryRoleResetRequested();
}
