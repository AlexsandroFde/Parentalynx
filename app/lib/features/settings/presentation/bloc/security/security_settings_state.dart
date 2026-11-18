part of 'security_settings_bloc.dart';

final class SecuritySettingsState extends Equatable {
  const SecuritySettingsState({this.timeout = AppLockTimeout.standard});

  /// Tempo escolhido. Comeca no padrao ate a preferencia gravada ser lida.
  final AppLockTimeout timeout;

  @override
  List<Object?> get props => <Object?>[timeout];
}
