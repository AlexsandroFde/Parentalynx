part of 'notification_prefs_bloc.dart';

sealed class NotificationPrefsEvent extends Equatable {
  const NotificationPrefsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu: acompanha as preferencias da conta.
final class NotificationPrefsStarted extends NotificationPrefsEvent {
  const NotificationPrefsStarted();
}

/// A pessoa ligou ou desligou a notificacao de um tipo de alerta.
final class NotificationPreferenceToggled extends NotificationPrefsEvent {
  const NotificationPreferenceToggled(this.type, {required this.enabled});

  final AlertType type;
  final bool enabled;

  @override
  List<Object?> get props => <Object?>[type, enabled];
}
