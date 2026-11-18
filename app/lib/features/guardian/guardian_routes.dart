import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import 'presentation/bloc/dashboard/guardian_dashboard_bloc.dart';
import 'presentation/bloc/shell/guardian_shell_bloc.dart';
import 'presentation/pages/dashboard_page.dart';
import 'presentation/widgets/guardian_shell.dart';

/// Casca das abas do painel do responsavel, com os [branches] na ordem das abas: Inicio,
/// Regras, Relatorios, Alertas ([GuardianShell.alertsTab]) e Mais.
///
/// A casca usa o `NotificationsBloc` e o `NotificationPermissionBloc` do escopo da sessao, que
/// precisam estar acima desta rota.
StatefulShellRoute guardianShellRoute(GetIt di, {required List<StatefulShellBranch> branches}) {
  return StatefulShellRoute.indexedStack(
    builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) {
      return BlocProvider<GuardianShellBloc>(
        create: (BuildContext context) {
          return di<GuardianShellBloc>()..add(const GuardianShellStarted());
        },
        child: GuardianShell(navigationShell: shell),
      );
    },
    branches: branches,
  );
}

/// Rotas da aba Inicio ([GuardianPaths.home]).
///
/// A tela usa o `DevicesBloc` do escopo da sessao (aparelho em foco), que precisa estar acima
/// das rotas.
List<RouteBase> dashboardRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: GuardianPaths.home,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<GuardianDashboardBloc>(
          create: (BuildContext context) => di<GuardianDashboardBloc>(),
          child: const DashboardPage(),
        );
      },
    ),
  ];
}
