import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import 'presentation/bloc/account/account_bloc.dart';
import 'presentation/bloc/account_settings/account_settings_bloc.dart';
import 'presentation/bloc/audit_log/audit_log_bloc.dart';
import 'presentation/bloc/change_password/change_password_bloc.dart';
import 'presentation/bloc/delete_account/delete_account_bloc.dart';
import 'presentation/bloc/more/more_bloc.dart';
import 'presentation/bloc/security/security_settings_bloc.dart';
import 'presentation/bloc/sessions/sessions_bloc.dart';
import 'presentation/pages/account_page.dart';
import 'presentation/pages/audit_log_page.dart';
import 'presentation/pages/more_page.dart';
import 'presentation/pages/privacy_page.dart';
import 'presentation/pages/security_page.dart';
import 'presentation/pages/sessions_page.dart';

/// Rotas da aba Mais ([GuardianPaths.more]) e das suas telas: conta, sessoes, bloqueio do
/// painel, privacidade e registro de alteracoes.
///
/// Cada tela recebe o seu BLoC, criado aqui. As telas esperam acima da arvore o `AuthBloc` e,
/// na aba Mais, o `DevicesBloc`.
List<RouteBase> settingsRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: GuardianPaths.more,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<MoreBloc>(
          create: (BuildContext context) => di<MoreBloc>()..add(const MoreStarted()),
          child: const MorePage(),
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'account',
          builder: (BuildContext context, GoRouterState state) {
            return BlocProvider<AccountBloc>(
              create: (BuildContext context) => di<AccountBloc>()..add(const AccountStarted()),
              child: AccountPage(
                changePasswordBloc: () => di<ChangePasswordBloc>(),
                deleteAccountBloc: () => di<DeleteAccountBloc>(),
              ),
            );
          },
        ),
        GoRoute(
          path: 'sessions',
          builder: (BuildContext context, GoRouterState state) {
            return BlocProvider<SessionsBloc>(
              create: (BuildContext context) =>
                  di<SessionsBloc>()..add(const SessionsLoadRequested()),
              child: const SessionsPage(),
            );
          },
        ),
        GoRoute(
          path: 'security',
          builder: (BuildContext context, GoRouterState state) {
            return BlocProvider<SecuritySettingsBloc>(
              create: (BuildContext context) =>
                  di<SecuritySettingsBloc>()..add(const SecuritySettingsStarted()),
              child: const SecurityPage(),
            );
          },
        ),
        GoRoute(
          path: 'privacy',
          builder: (BuildContext context, GoRouterState state) {
            return BlocProvider<AccountSettingsBloc>(
              create: (BuildContext context) =>
                  di<AccountSettingsBloc>()..add(const AccountSettingsStarted()),
              child: const PrivacyPage(),
            );
          },
        ),
        GoRoute(
          path: 'audit',
          builder: (BuildContext context, GoRouterState state) {
            return BlocProvider<AuditLogBloc>(
              create: (BuildContext context) =>
                  di<AuditLogBloc>()..add(const AuditLogLoadRequested()),
              child: const AuditLogPage(),
            );
          },
        ),
      ],
    ),
  ];
}
