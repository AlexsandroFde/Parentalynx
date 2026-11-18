import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/route_paths.dart';
import '../../features/activity_reports/activity_reports_routes.dart';
import '../../features/app_management/app_management_routes.dart';
import '../../features/app_management/presentation/overview/app_management_rule_groups.dart';
import '../../features/authentication/authentication_routes.dart';
import '../../features/authentication/presentation/bloc/auth/auth_bloc.dart';
import '../../features/blocking/blocking_routes.dart';
import '../../features/blocking/presentation/overview/blocking_rule_groups.dart';
import '../../features/child_device/child_device_routes.dart';
import '../../features/child_mode/child_mode_routes.dart';
import '../../features/device_linking/device_linking_routes.dart';
import '../../features/device_linking/presentation/bloc/child_link/child_link_bloc.dart';
import '../../features/device_policy/device_policy_routes.dart';
import '../../features/device_policy/presentation/overview/rule_group.dart';
import '../../features/guardian/guardian_routes.dart';
import '../../features/notifications/notifications_routes.dart';
import '../../features/onboarding/onboarding_routes.dart';
import '../../features/schedules/presentation/overview/schedule_rule_groups.dart';
import '../../features/schedules/schedules_routes.dart';
import '../../features/screen_time/presentation/overview/screen_time_rule_groups.dart';
import '../../features/screen_time/screen_time_routes.dart';
import '../../features/settings/settings_routes.dart';
import '../../features/user_role/domain/entities/user_role.dart';
import '../../features/user_role/presentation/bloc/user_role_bloc.dart';
import '../../shared/widgets/feedback_views.dart';
import 'guardian_session_scope.dart';
import 'router_refresh.dart';

/// Telas que so fazem sentido sem sessao.
const Set<String> _signedOutLocations = <String>{
  GuardianPaths.signIn,
  GuardianPaths.register,
  GuardianPaths.login,
  GuardianPaths.recover,
};

/// Telas de conta e de bloqueio. Com o painel aberto, a pessoa e levada para fora delas.
const Set<String> _accountLocations = <String>{
  ..._signedOutLocations,
  GuardianPaths.recoveryKey,
  GuardianPaths.unlock,
};

/// Roteador do app e o aviso de reavaliacao que ele observa.
final class AppRouter {
  AppRouter._(this.router, this._refresh);

  final GoRouter router;
  final RouterRefresh _refresh;

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }
}

/// Monta o roteador do app.
///
/// O redirecionamento de topo escolhe a area pelo perfil ([UserRoleBloc]): sem perfil vai para
/// as boas-vindas, responsavel fica sob `/guardian` e crianca sob `/child`. Dentro de cada area
/// decidem a sessao do responsavel ([AuthBloc]) e o vinculo da crianca ([ChildLinkBloc], pela
/// regra do modo crianca em [childRedirect]). Os tres BLoCs vivem enquanto o app vive; o
/// roteador so os observa.
AppRouter buildAppRouter(GetIt di, {required GlobalKey<NavigatorState> navigatorKey}) {
  final UserRoleBloc roles = di<UserRoleBloc>();
  final AuthBloc auth = di<AuthBloc>();
  final ChildLinkBloc childLink = di<ChildLinkBloc>();
  final ReturnLocation returnLocation = ReturnLocation();
  final RouterRefresh refresh = RouterRefresh(<Stream<Object?>>[
    roles.stream,
    auth.stream,
    childLink.stream,
  ]);

  String? guardianRedirect(GoRouterState state) {
    final String location = state.matchedLocation;
    switch (auth.state) {
      case AuthSignedOut():
        return _signedOutLocations.contains(location) ? null : GuardianPaths.signIn;
      case AuthLocked():
        // Bloqueado, so a tela de bloqueio e a recuperacao de acesso ficam alcancaveis.
        if (location == GuardianPaths.unlock || location == GuardianPaths.recover) {
          return null;
        }
        if (location != GuardianPaths.root && !_accountLocations.contains(location)) {
          returnLocation.remember(state.uri.toString());
        }
        return GuardianPaths.unlock;
      case AuthReady(:final String? pendingRecoveryKey):
        if (pendingRecoveryKey != null) {
          return location == GuardianPaths.recoveryKey ? null : GuardianPaths.recoveryKey;
        }
        if (location == GuardianPaths.root || _accountLocations.contains(location)) {
          // Depois de desbloquear, volta para onde a pessoa estava.
          return returnLocation.take() ?? GuardianPaths.home;
        }
        return null;
    }
  }

  final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      switch (roles.state.role) {
        case UserRole.unset:
          return location.startsWith(OnboardingPaths.welcome) ? null : OnboardingPaths.welcome;
        case UserRole.guardian:
          return location.startsWith(GuardianPaths.root)
              ? guardianRedirect(state)
              : GuardianPaths.root;
        case UserRole.child:
          return location.startsWith(ChildPaths.root)
              ? childRedirect(childLink.state.phase, location)
              : ChildPaths.root;
      }
    },
    routes: <RouteBase>[
      // A raiz nunca e exibida: o redirecionamento sempre leva a uma das areas.
      GoRoute(path: '/', redirect: (BuildContext context, GoRouterState state) => null),
      ...onboardingRoutes(di),
      GoRoute(
        path: GuardianPaths.root,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: LoadingView());
        },
      ),
      ...authenticationRoutes(di),
      _guardianPanel(di),
      childShellRoute(di),
    ],
  );
  return AppRouter._(router, refresh);
}

/// Painel do responsavel com a sessao aberta: as cinco abas, a vinculacao e os aparelhos,
/// todos dentro do escopo da sessao.
ShellRoute _guardianPanel(GetIt di) {
  return ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) {
      return GuardianSessionScope(di: di, child: child);
    },
    routes: <RouteBase>[
      guardianShellRoute(
        di,
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: dashboardRoutes(di)),
          StatefulShellBranch(
            routes: <RouteBase>[
              rulesOverviewRoute(
                di,
                groups: <RuleGroup>[
                  ...screenTimeRuleGroups,
                  ...scheduleRuleGroups,
                  ...appManagementRuleGroups,
                  ...blockingRuleGroups,
                ],
                routes: <RouteBase>[
                  ...screenTimeRuleRoutes(di),
                  ...scheduleRuleRoutes(di),
                  ...appManagementRuleRoutes(di),
                  ...blockingRuleRoutes(di),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: activityReportsRoutes(di)),
          StatefulShellBranch(
            routes: <RouteBase>[alertsRoute(di, children: screenTimeAlertRoutes(di))],
          ),
          StatefulShellBranch(routes: settingsRoutes(di)),
        ],
      ),
      ...deviceLinkingRoutes(di),
      ...childDeviceRoutes(di),
    ],
  );
}
