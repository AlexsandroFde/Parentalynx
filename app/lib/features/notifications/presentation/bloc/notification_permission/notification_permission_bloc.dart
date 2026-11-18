import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../domain/usecases/check_notification_permission.dart';
import '../../../domain/usecases/open_notification_settings.dart';
import '../../../domain/usecases/request_notification_permission.dart';
import '../../../domain/usecases/should_prompt_for_notifications.dart';

part 'notification_permission_event.dart';
part 'notification_permission_state.dart';

/// Permissao de notificacoes do sistema, compartilhada pelo painel: a casca (pedido da
/// primeira vez), a central de alertas e as preferencias (aviso de notificacoes desligadas).
class NotificationPermissionBloc
    extends Bloc<NotificationPermissionEvent, NotificationPermissionState> {
  NotificationPermissionBloc({
    required this._check,
    required this._request,
    required this._openSettings,
    required this._shouldPrompt,
  }) : super(const NotificationPermissionState()) {
    on<NotificationPermissionStarted>(_onStarted, transformer: restartable());
    on<NotificationFirstRunCheckRequested>(_onFirstRunCheck, transformer: droppable());
    on<NotificationFirstRunPromptShown>(_onFirstRunPromptShown);
    on<NotificationPermissionRequested>(_onRequested, transformer: droppable());
    on<NotificationSettingsOpened>(_onSettingsOpened, transformer: droppable());
  }

  final CheckNotificationPermission _check;
  final RequestNotificationPermission _request;
  final OpenNotificationSettings _openSettings;
  final ShouldPromptForNotifications _shouldPrompt;

  Future<void> _onStarted(
    NotificationPermissionStarted event,
    Emitter<NotificationPermissionState> emit,
  ) async {
    emit(state.copyWith(status: _statusOf(await _check())));
  }

  Future<void> _onFirstRunCheck(
    NotificationFirstRunCheckRequested event,
    Emitter<NotificationPermissionState> emit,
  ) async {
    if (await _shouldPrompt()) {
      emit(state.copyWith(firstRunPrompt: true));
    }
  }

  void _onFirstRunPromptShown(
    NotificationFirstRunPromptShown event,
    Emitter<NotificationPermissionState> emit,
  ) {
    emit(state.copyWith(firstRunPrompt: false));
  }

  Future<void> _onRequested(
    NotificationPermissionRequested event,
    Emitter<NotificationPermissionState> emit,
  ) async {
    bool granted = false;
    try {
      granted = await _request();
      // Confere de novo no sistema, que e a referencia.
      emit(state.copyWith(status: _statusOf(await _check())));
    } finally {
      event.completer?.complete(granted);
    }
  }

  Future<void> _onSettingsOpened(
    NotificationSettingsOpened event,
    Emitter<NotificationPermissionState> emit,
  ) {
    return _openSettings();
  }

  static NotificationPermissionStatus _statusOf(bool allowed) {
    return allowed ? NotificationPermissionStatus.allowed : NotificationPermissionStatus.denied;
  }
}
