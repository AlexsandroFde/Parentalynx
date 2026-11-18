part of 'guardian_area_bloc.dart';

sealed class GuardianAreaEvent extends Equatable {
  const GuardianAreaEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Alterna entre pedir a senha e pedir o codigo de acesso offline.
final class GuardianAreaModeToggled extends GuardianAreaEvent {
  const GuardianAreaModeToggled();
}

final class GuardianAreaPasswordSubmitted extends GuardianAreaEvent {
  const GuardianAreaPasswordSubmitted(this.password);

  final String password;

  @override
  List<Object?> get props => <Object?>[password];
}

final class GuardianAreaCodeSubmitted extends GuardianAreaEvent {
  const GuardianAreaCodeSubmitted(this.code);

  final String code;

  @override
  List<Object?> get props => <Object?>[code];
}

/// O responsavel saiu da area: a proxima visita pede a senha de novo.
final class GuardianAreaLeft extends GuardianAreaEvent {
  const GuardianAreaLeft();
}

/// Liberar o uso do aparelho por alguns minutos.
final class GuardianAreaOverrideGranted extends GuardianAreaEvent {
  const GuardianAreaOverrideGranted(this.minutes);

  final int minutes;

  @override
  List<Object?> get props => <Object?>[minutes];
}

/// Encerrar a liberacao antes do tempo.
final class GuardianAreaOverrideCleared extends GuardianAreaEvent {
  const GuardianAreaOverrideCleared();
}

final class GuardianAreaDeviceAdminRequested extends GuardianAreaEvent {
  const GuardianAreaDeviceAdminRequested();
}

/// Desativar o administrador (a tela ja pediu a confirmacao).
final class GuardianAreaDeviceAdminRemoved extends GuardianAreaEvent {
  const GuardianAreaDeviceAdminRemoved();
}

/// Deixar de gerenciar o aparelho (a tela ja pediu a confirmacao).
final class GuardianAreaOwnershipReleased extends GuardianAreaEvent {
  const GuardianAreaOwnershipReleased();
}

/// Desvincular este aparelho (a tela ja pediu a confirmacao).
final class GuardianAreaUnlinkRequested extends GuardianAreaEvent {
  const GuardianAreaUnlinkRequested();
}
