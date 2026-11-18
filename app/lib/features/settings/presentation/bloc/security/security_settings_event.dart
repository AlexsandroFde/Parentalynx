part of 'security_settings_bloc.dart';

sealed class SecuritySettingsEvent extends Equatable {
  const SecuritySettingsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu: le o tempo escolhido.
final class SecuritySettingsStarted extends SecuritySettingsEvent {
  const SecuritySettingsStarted();
}

/// A pessoa escolheu outro tempo de bloqueio.
final class AppLockTimeoutSelected extends SecuritySettingsEvent {
  const AppLockTimeoutSelected(this.timeout);

  final AppLockTimeout timeout;

  @override
  List<Object?> get props => <Object?>[timeout];
}
