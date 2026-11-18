import 'package:get_it/get_it.dart';

import '../../core/platform/native_api.g.dart';
import 'data/repositories/native_user_role_repository.dart';
import 'domain/entities/user_role.dart';
import 'domain/repositories/i_user_role_repository.dart';
import 'domain/usecases/change_user_role.dart';
import 'domain/usecases/watch_user_role.dart';
import 'presentation/bloc/user_role_bloc.dart';

/// Registra as dependencias do perfil do app.
///
/// [initialRole] e lido do lado nativo antes do primeiro quadro, no bootstrap.
void registerUserRoleModule(GetIt di, {required UserRole initialRole}) {
  di
    ..registerLazySingleton<IUserRoleRepository>(
      () => NativeUserRoleRepository(api: di<AppModeApi>(), initialRole: initialRole),
    )
    ..registerFactory<ChangeUserRole>(() => ChangeUserRole(di<IUserRoleRepository>()))
    ..registerFactory<WatchUserRole>(() => WatchUserRole(di<IUserRoleRepository>()))
    // Vive enquanto o app vive: o roteador observa o perfil o tempo todo.
    ..registerLazySingleton<UserRoleBloc>(
      () =>
          UserRoleBloc(watchUserRole: di<WatchUserRole>())
            ..add(const UserRoleSubscriptionRequested()),
      dispose: (UserRoleBloc bloc) => bloc.close(),
    );
}
