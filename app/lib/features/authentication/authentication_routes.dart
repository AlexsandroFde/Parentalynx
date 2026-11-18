import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import 'presentation/bloc/guardian_entry/guardian_entry_bloc.dart';
import 'presentation/bloc/login/login_bloc.dart';
import 'presentation/bloc/recover_access/recover_access_bloc.dart';
import 'presentation/bloc/register/register_bloc.dart';
import 'presentation/bloc/unlock/unlock_bloc.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/recover_page.dart';
import 'presentation/pages/recovery_key_page.dart';
import 'presentation/pages/register_page.dart';
import 'presentation/pages/sign_in_page.dart';
import 'presentation/pages/unlock_page.dart';

/// Rotas das telas de conta do responsavel. Cada tela recebe o seu BLoC, criado aqui e
/// fechado quando a tela sai da pilha.
List<RouteBase> authenticationRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: GuardianPaths.signIn,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<GuardianEntryBloc>(
          create: (BuildContext context) =>
              di<GuardianEntryBloc>()..add(const GuardianEntryStarted()),
          child: const SignInPage(),
        );
      },
    ),
    GoRoute(
      path: GuardianPaths.register,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<RegisterBloc>(
          create: (BuildContext context) => di<RegisterBloc>()..add(const RegisterStarted()),
          child: const RegisterPage(),
        );
      },
    ),
    GoRoute(
      path: GuardianPaths.login,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<LoginBloc>(
          create: (BuildContext context) => di<LoginBloc>(),
          child: const LoginPage(),
        );
      },
    ),
    GoRoute(
      path: GuardianPaths.recover,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<RecoverAccessBloc>(
          create: (BuildContext context) {
            return di<RecoverAccessBloc>()..add(const RecoverAccessStarted());
          },
          child: const RecoverPage(),
        );
      },
    ),
    GoRoute(
      path: GuardianPaths.recoveryKey,
      builder: (BuildContext context, GoRouterState state) => const RecoveryKeyPage(),
    ),
    GoRoute(
      path: GuardianPaths.unlock,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<UnlockBloc>(
          create: (BuildContext context) => di<UnlockBloc>()..add(const UnlockStarted()),
          child: const UnlockPage(),
        );
      },
    ),
  ];
}
