import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/network/server_endpoint.dart';
import '../../core/platform/native_api.g.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/time/clock.dart';
import '../authentication/domain/repositories/i_current_account_repository.dart';
import '../authentication/domain/usecases/watch_guardian_session.dart';
import '../device_sync/domain/usecases/watch_realtime_updates.dart';
import 'data/datasources/remote/alerts_remote_data_source.dart';
import 'data/repositories/api_alerts_repository.dart';
import 'data/repositories/local_notification_prompt_repository.dart';
import 'data/services/native_alert_polling_service.dart';
import 'data/services/native_notification_permission_service.dart';
import 'domain/repositories/i_alerts_repository.dart';
import 'domain/repositories/i_notification_prompt_repository.dart';
import 'domain/services/alert_polling_coordinator.dart';
import 'domain/services/i_alert_polling_service.dart';
import 'domain/services/i_notification_permission_service.dart';
import 'domain/usecases/check_notification_permission.dart';
import 'domain/usecases/get_recent_alerts.dart';
import 'domain/usecases/get_unread_alerts_count.dart';
import 'domain/usecases/load_latest_alerts.dart';
import 'domain/usecases/load_older_alerts.dart';
import 'domain/usecases/mark_alert_read.dart';
import 'domain/usecases/mark_alerts_seen.dart';
import 'domain/usecases/mark_all_alerts_read.dart';
import 'domain/usecases/open_notification_settings.dart';
import 'domain/usecases/request_notification_permission.dart';
import 'domain/usecases/should_prompt_for_notifications.dart';
import 'domain/usecases/update_notification_preference.dart';
import 'domain/usecases/watch_incoming_alerts.dart';
import 'domain/usecases/watch_notification_preferences.dart';
import 'presentation/bloc/notification_permission/notification_permission_bloc.dart';
import 'presentation/bloc/notification_prefs/notification_prefs_bloc.dart';
import 'presentation/bloc/notifications/notifications_bloc.dart';

/// Registra as dependencias de alertas e notificacoes do responsavel.
///
/// O [AlertPollingCoordinator] precisa ser iniciado uma vez na inicializacao do app
/// (`di<AlertPollingCoordinator>().start()`), para acompanhar a sessao desde o comeco.
void registerNotificationsModule(GetIt di) {
  // Dados.
  di
    ..registerLazySingleton<AlertsRemoteDataSource>(() => AlertsRemoteDataSource(di<ApiClient>()))
    ..registerLazySingleton<IAlertsRepository>(
      () => ApiAlertsRepository(di<AlertsRemoteDataSource>()),
    )
    ..registerLazySingleton<INotificationPromptRepository>(
      () => LocalNotificationPromptRepository(di<LocalPreferences>()),
    )
    ..registerLazySingleton<IAlertPollingService>(
      () => NativeAlertPollingService(api: di<GuardianNativeApi>(), endpoint: di<ServerEndpoint>()),
    )
    ..registerLazySingleton<INotificationPermissionService>(
      () => NativeNotificationPermissionService(di<DeviceApi>()),
    )
    // Observa a sessao durante toda a vida do app.
    ..registerLazySingleton<AlertPollingCoordinator>(
      () => AlertPollingCoordinator(
        session: di<WatchGuardianSession>(),
        polling: di<IAlertPollingService>(),
      ),
      dispose: (AlertPollingCoordinator coordinator) => coordinator.stop(),
    );

  // Casos de uso.
  di
    ..registerFactory<LoadLatestAlerts>(
      () => LoadLatestAlerts(alerts: di<IAlertsRepository>(), polling: di<IAlertPollingService>()),
    )
    ..registerFactory<LoadOlderAlerts>(() => LoadOlderAlerts(di<IAlertsRepository>()))
    ..registerFactory<GetUnreadAlertsCount>(() => GetUnreadAlertsCount(di<IAlertsRepository>()))
    ..registerFactory<GetRecentAlerts>(() => GetRecentAlerts(di<IAlertsRepository>()))
    ..registerFactory<MarkAlertRead>(() => MarkAlertRead(di<IAlertsRepository>()))
    ..registerFactory<MarkAllAlertsRead>(() => MarkAllAlertsRead(di<IAlertsRepository>()))
    ..registerFactory<MarkAlertsSeen>(() => MarkAlertsSeen(di<IAlertPollingService>()))
    ..registerFactory<WatchIncomingAlerts>(() => WatchIncomingAlerts(di<WatchRealtimeUpdates>()))
    ..registerFactory<WatchNotificationPreferences>(
      () => WatchNotificationPreferences(di<ICurrentAccountRepository>()),
    )
    ..registerFactory<UpdateNotificationPreference>(
      () => UpdateNotificationPreference(
        alerts: di<IAlertsRepository>(),
        account: di<ICurrentAccountRepository>(),
      ),
    )
    ..registerFactory<CheckNotificationPermission>(
      () => CheckNotificationPermission(di<INotificationPermissionService>()),
    )
    ..registerFactory<RequestNotificationPermission>(
      () => RequestNotificationPermission(di<INotificationPermissionService>()),
    )
    ..registerFactory<OpenNotificationSettings>(
      () => OpenNotificationSettings(di<INotificationPermissionService>()),
    )
    ..registerFactory<ShouldPromptForNotifications>(
      () => ShouldPromptForNotifications(
        prompts: di<INotificationPromptRepository>(),
        permission: di<INotificationPermissionService>(),
      ),
    );

  // Apresentacao.
  di
    // Um por painel aberto (escopo da sessao): selo, central e avisos em tempo real.
    ..registerFactory<NotificationsBloc>(
      () => NotificationsBloc(
        loadLatest: di<LoadLatestAlerts>(),
        loadOlder: di<LoadOlderAlerts>(),
        unreadCount: di<GetUnreadAlertsCount>(),
        markRead: di<MarkAlertRead>(),
        markAllRead: di<MarkAllAlertsRead>(),
        incoming: di<WatchIncomingAlerts>(),
        markSeen: di<MarkAlertsSeen>(),
        clock: di<Clock>(),
      ),
    )
    // Um por painel aberto (escopo da sessao).
    ..registerFactory<NotificationPermissionBloc>(
      () => NotificationPermissionBloc(
        check: di<CheckNotificationPermission>(),
        request: di<RequestNotificationPermission>(),
        openSettings: di<OpenNotificationSettings>(),
        shouldPrompt: di<ShouldPromptForNotifications>(),
      ),
    )
    // Um por tela de preferencias aberta.
    ..registerFactory<NotificationPrefsBloc>(
      () => NotificationPrefsBloc(
        watchPreferences: di<WatchNotificationPreferences>(),
        updatePreference: di<UpdateNotificationPreference>(),
      ),
    );
}
