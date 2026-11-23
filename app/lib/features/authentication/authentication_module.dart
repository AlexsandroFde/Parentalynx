import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/network/api_client.dart';
import '../../core/network/session_credentials.dart';
import '../../core/platform/native_api.g.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/storage/secure_store.dart';
import '../../core/time/clock.dart';
import '../user_role/domain/usecases/change_user_role.dart';
import 'data/datasources/local/session_local_data_source.dart';
import 'data/datasources/remote/auth_remote_data_source.dart';
import 'data/repositories/api_auth_repository.dart';
import 'data/repositories/app_lock_repository.dart';
import 'data/repositories/guardian_session_store.dart';
import 'data/services/native_guardian_device_service.dart';
import 'domain/repositories/i_app_lock_repository.dart';
import 'domain/repositories/i_auth_repository.dart';
import 'domain/repositories/i_current_account_repository.dart';
import 'domain/repositories/i_session_repository.dart';
import 'domain/services/i_elevation_prompter.dart';
import 'domain/services/i_guardian_device_service.dart';
import 'domain/usecases/acknowledge_recovery_key.dart';
import 'domain/usecases/app_lock_preference.dart';
import 'domain/usecases/elevate_session.dart';
import 'domain/usecases/end_session.dart';
import 'domain/usecases/get_sign_in_defaults.dart';
import 'domain/usecases/lock_session.dart';
import 'domain/usecases/recover_access.dart';
import 'domain/usecases/refresh_account.dart';
import 'domain/usecases/register_guardian.dart';
import 'domain/usecases/run_elevated.dart';
import 'domain/usecases/sign_in.dart';
import 'domain/usecases/sign_out.dart';
import 'domain/usecases/unlock_session.dart';
import 'domain/usecases/watch_guardian_session.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/elevation/elevation_bloc.dart';
import 'presentation/bloc/guardian_entry/guardian_entry_bloc.dart';
import 'presentation/bloc/login/login_bloc.dart';
import 'presentation/bloc/recover_access/recover_access_bloc.dart';
import 'presentation/bloc/register/register_bloc.dart';
import 'presentation/bloc/unlock/unlock_bloc.dart';
import 'presentation/dialogs/elevation_dialog.dart';

/// Registra as dependencias de autenticacao e sessao do responsavel.
///
/// [navigatorKey] e o navegador raiz, usado para mostrar o pedido de senha a partir de
/// qualquer caso de uso administrativo.
void registerAuthenticationModule(GetIt di, {required GlobalKey<NavigatorState> navigatorKey}) {
  // Dados.
  di
    ..registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSource(di<ApiClient>()))
    ..registerLazySingleton<SessionLocalDataSource>(
      () => SessionLocalDataSource(credentials: di<SessionCredentials>(), store: di<SecureStore>()),
    )
    ..registerLazySingleton<IAuthRepository>(() => ApiAuthRepository(di<AuthRemoteDataSource>()))
    // Uma unica instancia atende as duas visoes da sessao.
    ..registerLazySingleton<GuardianSessionStore>(
      () => GuardianSessionStore(di<SessionLocalDataSource>()),
    )
    ..registerLazySingleton<ISessionRepository>(() => di<GuardianSessionStore>())
    ..registerLazySingleton<ICurrentAccountRepository>(() => di<GuardianSessionStore>())
    ..registerLazySingleton<IAppLockRepository>(() => AppLockRepository(di<LocalPreferences>()))
    ..registerLazySingleton<IGuardianDeviceService>(
      () => NativeGuardianDeviceService(di<DeviceApi>()),
    )
    ..registerLazySingleton<IElevationPrompter>(
      () => DialogElevationPrompter(
        navigatorKey: navigatorKey,
        createBloc: () => di<ElevationBloc>(),
      ),
    );

  // Casos de uso.
  di
    ..registerFactory<SignIn>(
      () => SignIn(
        auth: di<IAuthRepository>(),
        session: di<ISessionRepository>(),
        device: di<IGuardianDeviceService>(),
      ),
    )
    ..registerFactory<RegisterGuardian>(
      () => RegisterGuardian(auth: di<IAuthRepository>(), session: di<ISessionRepository>()),
    )
    ..registerFactory<RecoverAccess>(
      () => RecoverAccess(
        auth: di<IAuthRepository>(),
        session: di<ISessionRepository>(),
        device: di<IGuardianDeviceService>(),
      ),
    )
    ..registerFactory<UnlockSession>(
      () => UnlockSession(auth: di<IAuthRepository>(), session: di<ISessionRepository>()),
    )
    ..registerFactory<LockSession>(
      () => LockSession(session: di<ISessionRepository>(), preferences: di<IAppLockRepository>()),
    )
    ..registerFactory<SignOut>(
      () => SignOut(auth: di<IAuthRepository>(), session: di<ISessionRepository>()),
    )
    ..registerFactory<EndSession>(() => EndSession(di<ISessionRepository>()))
    ..registerFactory<AcknowledgeRecoveryKey>(
      () => AcknowledgeRecoveryKey(di<ISessionRepository>()),
    )
    ..registerFactory<RefreshAccount>(
      () => RefreshAccount(auth: di<IAuthRepository>(), account: di<ICurrentAccountRepository>()),
    )
    ..registerFactory<WatchGuardianSession>(() => WatchGuardianSession(di<ISessionRepository>()))
    ..registerFactory<GetSignInDefaults>(
      () => GetSignInDefaults(
        session: di<ISessionRepository>(),
        device: di<IGuardianDeviceService>(),
      ),
    )
    ..registerFactory<ElevateSession>(() => ElevateSession(di<IAuthRepository>()))
    ..registerFactory<RunElevated>(() => RunElevated(di<IElevationPrompter>()))
    ..registerFactory<AppLockPreference>(() => AppLockPreference(di<IAppLockRepository>()));

  // Apresentacao.
  di
    // Vive enquanto o app vive: o roteador observa a sessao o tempo todo.
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(
        watchSession: di<WatchGuardianSession>(),
        lockSession: di<LockSession>(),
        signOut: di<SignOut>(),
        endSession: di<EndSession>(),
        acknowledgeRecoveryKey: di<AcknowledgeRecoveryKey>(),
        refreshAccount: di<RefreshAccount>(),
        clock: di<Clock>(),
      )..add(const AuthSubscriptionRequested()),
      dispose: (AuthBloc bloc) => bloc.close(),
    )
    // Uma instancia por tela de conta, fechada quando a tela sai.
    ..registerFactory<LoginBloc>(() => LoginBloc(signIn: di<SignIn>()))
    ..registerFactory<RegisterBloc>(
      () => RegisterBloc(register: di<RegisterGuardian>(), defaults: di<GetSignInDefaults>()),
    )
    ..registerFactory<RecoverAccessBloc>(
      () =>
          RecoverAccessBloc(recoverAccess: di<RecoverAccess>(), defaults: di<GetSignInDefaults>()),
    )
    ..registerFactory<UnlockBloc>(
      () => UnlockBloc(
        unlockSession: di<UnlockSession>(),
        session: di<WatchGuardianSession>(),
        defaults: di<GetSignInDefaults>(),
      ),
    )
    ..registerFactory<ElevationBloc>(() => ElevationBloc(elevateSession: di<ElevateSession>()))
    ..registerFactory<GuardianEntryBloc>(
      () => GuardianEntryBloc(changeUserRole: di<ChangeUserRole>()),
    );
}
