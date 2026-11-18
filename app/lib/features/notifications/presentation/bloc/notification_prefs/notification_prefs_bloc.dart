import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/alert_type.dart';
import '../../../domain/entities/notification_preferences.dart';
import '../../../domain/usecases/update_notification_preference.dart';
import '../../../domain/usecases/watch_notification_preferences.dart';

part 'notification_prefs_event.dart';
part 'notification_prefs_state.dart';

/// Preferencias de notificacao: um interruptor por tipo de alerta.
///
/// A mudanca aparece na hora e e desfeita se o servidor recusar (ver
/// [UpdateNotificationPreference]). Tipos diferentes podem ser gravados ao mesmo tempo.
class NotificationPrefsBloc extends Bloc<NotificationPrefsEvent, NotificationPrefsState> {
  NotificationPrefsBloc({required this._watchPreferences, required this._updatePreference})
    : super(const NotificationPrefsState()) {
    on<NotificationPrefsStarted>(_onStarted, transformer: restartable());
    on<NotificationPreferenceToggled>(_onToggled, transformer: concurrent());
  }

  final WatchNotificationPreferences _watchPreferences;
  final UpdateNotificationPreference _updatePreference;

  Future<void> _onStarted(NotificationPrefsStarted event, Emitter<NotificationPrefsState> emit) {
    return emit.forEach<NotificationPreferences?>(
      _watchPreferences(),
      onData: (NotificationPreferences? preferences) {
        return NotificationPrefsState(
          preferences: preferences,
          saving: state.saving,
          action: state.action,
        );
      },
    );
  }

  Future<void> _onToggled(
    NotificationPreferenceToggled event,
    Emitter<NotificationPrefsState> emit,
  ) async {
    if (state.saving.contains(event.type)) {
      return;
    }
    emit(
      state.copyWith(
        saving: <AlertType>{...state.saving, event.type},
        action: const ActionRunning(),
      ),
    );
    final Result<Map<String, bool>> result = await _updatePreference(
      event.type,
      enabled: event.enabled,
    );
    final Set<AlertType> saving = <AlertType>{...state.saving}..remove(event.type);
    switch (result) {
      case Ok<Map<String, bool>>():
        emit(state.copyWith(saving: saving, action: const ActionIdle()));
      case Err<Map<String, bool>>(:final AppFailure failure):
        emit(state.copyWith(saving: saving, action: actionStatusForFailure(failure)));
    }
  }
}
