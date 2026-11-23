import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/network/server_endpoint.dart';
import '../../core/platform/native_api.g.dart';
import '../authentication/domain/repositories/i_current_account_repository.dart';
import '../authentication/domain/usecases/app_lock_preference.dart';
import '../authentication/domain/usecases/end_session.dart';
import '../authentication/domain/usecases/run_elevated.dart';
import 'data/datasources/remote/account_remote_data_source.dart';
import 'data/repositories/api_account_management_repository.dart';
import 'data/services/native_app_info_service.dart';
import 'domain/repositories/i_account_management_repository.dart';
import 'domain/services/i_app_info_service.dart';
import 'domain/usecases/change_password.dart';
import 'domain/usecases/delete_account.dart';
import 'domain/usecases/get_app_version.dart';
import 'domain/usecases/list_guardian_sessions.dart';
import 'domain/usecases/load_audit_log.dart';
import 'domain/usecases/regenerate_recovery_key.dart';
import 'domain/usecases/revoke_guardian_session.dart';
import 'domain/usecases/update_account_settings.dart';
import 'domain/usecases/update_display_name.dart';
import 'domain/usecases/watch_current_account.dart';
import 'presentation/bloc/account/account_bloc.dart';
import 'presentation/bloc/account_settings/account_settings_bloc.dart';
import 'presentation/bloc/audit_log/audit_log_bloc.dart';
import 'presentation/bloc/change_password/change_password_bloc.dart';
import 'presentation/bloc/delete_account/delete_account_bloc.dart';
import 'presentation/bloc/more/more_bloc.dart';
import 'presentation/bloc/security/security_settings_bloc.dart';
import 'presentation/bloc/sessions/sessions_bloc.dart';

/// Registra as dependencias da aba Mais: conta, sessoes, bloqueio do painel, privacidade e
/// registro de alteracoes.
///
/// Depende dos modulos de autenticacao (conta em memoria, elevacao, fim da sessao e tempo de
/// bloqueio) e de configuracao do servidor (endereco em uso).
void registerSettingsModule(GetIt di) {
  // Dados.
  di
    ..registerLazySingleton<AccountRemoteDataSource>(() => AccountRemoteDataSource(di<ApiClient>()))
    ..registerLazySingleton<IAccountManagementRepository>(
      () => ApiAccountManagementRepository(di<AccountRemoteDataSource>()),
    )
    ..registerLazySingleton<IAppInfoService>(() => NativeAppInfoService(di<DeviceApi>()));

  // Casos de uso.
  di
    ..registerFactory<WatchCurrentAccount>(
      () => WatchCurrentAccount(di<ICurrentAccountRepository>()),
    )
    ..registerFactory<UpdateDisplayName>(
      () => UpdateDisplayName(
        repository: di<IAccountManagementRepository>(),
        account: di<ICurrentAccountRepository>(),
        runElevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<UpdateAccountSettings>(
      () => UpdateAccountSettings(
        repository: di<IAccountManagementRepository>(),
        account: di<ICurrentAccountRepository>(),
        runElevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<ChangePassword>(() => ChangePassword(di<IAccountManagementRepository>()))
    ..registerFactory<RegenerateRecoveryKey>(
      () => RegenerateRecoveryKey(di<IAccountManagementRepository>()),
    )
    ..registerFactory<ListGuardianSessions>(
      () => ListGuardianSessions(di<IAccountManagementRepository>()),
    )
    ..registerFactory<RevokeGuardianSession>(
      () => RevokeGuardianSession(
        repository: di<IAccountManagementRepository>(),
        runElevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<DeleteAccount>(
      () => DeleteAccount(
        repository: di<IAccountManagementRepository>(),
        endSession: di<EndSession>(),
      ),
    )
    ..registerFactory<LoadAuditLog>(() => LoadAuditLog(di<IAccountManagementRepository>()))
    ..registerFactory<GetAppVersion>(() => GetAppVersion(di<IAppInfoService>()));

  // Apresentacao: uma instancia por tela, fechada quando a tela sai.
  di
    ..registerFactory<MoreBloc>(
      () => MoreBloc(serverAddress: di<ServerEndpoint>().url, getAppVersion: di<GetAppVersion>()),
    )
    ..registerFactory<AccountBloc>(
      () => AccountBloc(
        watchAccount: di<WatchCurrentAccount>(),
        updateDisplayName: di<UpdateDisplayName>(),
        regenerateRecoveryKey: di<RegenerateRecoveryKey>(),
      ),
    )
    ..registerFactory<ChangePasswordBloc>(
      () => ChangePasswordBloc(
        changePassword: di<ChangePassword>(),
        account: di<WatchCurrentAccount>(),
      ),
    )
    ..registerFactory<DeleteAccountBloc>(
      () =>
          DeleteAccountBloc(deleteAccount: di<DeleteAccount>(), account: di<WatchCurrentAccount>()),
    )
    ..registerFactory<SessionsBloc>(
      () => SessionsBloc(
        listSessions: di<ListGuardianSessions>(),
        revokeSession: di<RevokeGuardianSession>(),
      ),
    )
    ..registerFactory<SecuritySettingsBloc>(
      () => SecuritySettingsBloc(appLock: di<AppLockPreference>()),
    )
    ..registerFactory<AccountSettingsBloc>(
      () => AccountSettingsBloc(
        watchAccount: di<WatchCurrentAccount>(),
        updateSettings: di<UpdateAccountSettings>(),
      ),
    )
    ..registerFactory<AuditLogBloc>(() => AuditLogBloc(loadAuditLog: di<LoadAuditLog>()));
}
