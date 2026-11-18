part of 'account_settings_bloc.dart';

sealed class AccountSettingsEvent extends Equatable {
  const AccountSettingsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu: acompanha os ajustes da conta em memoria.
final class AccountSettingsStarted extends AccountSettingsEvent {
  const AccountSettingsStarted();
}

/// A pessoa escolheu outro valor para um ajuste. [settings] traz todos os ajustes, com o
/// valor novo.
final class AccountSettingsChanged extends AccountSettingsEvent {
  const AccountSettingsChanged(this.settings);

  final GuardianSettings settings;

  @override
  List<Object?> get props => <Object?>[settings];
}
