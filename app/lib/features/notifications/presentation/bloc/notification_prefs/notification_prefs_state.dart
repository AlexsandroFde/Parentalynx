part of 'notification_prefs_bloc.dart';

final class NotificationPrefsState extends Equatable {
  const NotificationPrefsState({
    this.preferences,
    this.saving = const <AlertType>{},
    this.action = const ActionIdle(),
  });

  /// Preferencias da conta. Nulo enquanto o painel nao esta aberto.
  final NotificationPreferences? preferences;

  /// Tipos com gravacao em andamento: o interruptor correspondente fica desabilitado.
  final Set<AlertType> saving;

  /// Andamento da ultima gravacao, para avisar quando o servidor recusa.
  final ActionStatus action;

  NotificationPrefsState copyWith({
    NotificationPreferences? preferences,
    Set<AlertType>? saving,
    ActionStatus? action,
  }) {
    return NotificationPrefsState(
      preferences: preferences ?? this.preferences,
      saving: saving ?? this.saving,
      action: action ?? this.action,
    );
  }

  @override
  List<Object?> get props => <Object?>[preferences, saving, action];
}
