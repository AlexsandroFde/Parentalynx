import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/feedback_views.dart';
import 'alerts/presentation/alerts_center_page.dart';
import 'alerts/presentation/notification_prefs_page.dart';
import 'auth/presentation/login_page.dart';
import 'auth/presentation/recover_page.dart';
import 'auth/presentation/recovery_key_page.dart';
import 'auth/presentation/register_page.dart';
import 'auth/presentation/session_controller.dart';
import 'auth/presentation/sign_in_page.dart';
import 'auth/presentation/unlock_page.dart';
import 'dashboard/dashboard_routes.dart';
import 'devices/presentation/device_detail_page.dart';
import 'devices/presentation/devices_page.dart';
import 'guardian_paths.dart';
import 'pairing/presentation/pairing_page.dart';
import 'reports/reports_routes.dart';
import 'rules/rules_routes.dart';
import 'settings/presentation/account_page.dart';
import 'settings/presentation/audit_page.dart';
import 'settings/presentation/more_page.dart';
import 'settings/presentation/privacy_page.dart';
import 'settings/presentation/sessions_page.dart';
import 'shell/presentation/guardian_shell.dart';
import 'time_requests/presentation/time_requests_page.dart';

export 'guardian_paths.dart';

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

/// Rotas do modo responsavel.
final List<RouteBase> guardianRoutes = <RouteBase>[
  // A raiz nunca e exibida: o redirecionamento sempre leva a uma tela concreta.
  GoRoute(
    path: GuardianPaths.root,
    builder: (BuildContext context, GoRouterState state) => const Scaffold(body: LoadingView()),
  ),
  GoRoute(
    path: GuardianPaths.signIn,
    builder: (BuildContext context, GoRouterState state) => const SignInPage(),
  ),
  GoRoute(
    path: GuardianPaths.register,
    builder: (BuildContext context, GoRouterState state) => const RegisterPage(),
  ),
  GoRoute(
    path: GuardianPaths.login,
    builder: (BuildContext context, GoRouterState state) => const LoginPage(),
  ),
  GoRoute(
    path: GuardianPaths.recover,
    builder: (BuildContext context, GoRouterState state) => const RecoverPage(),
  ),
  GoRoute(
    path: GuardianPaths.recoveryKey,
    builder: (BuildContext context, GoRouterState state) => const RecoveryKeyPage(),
  ),
  GoRoute(
    path: GuardianPaths.unlock,
    builder: (BuildContext context, GoRouterState state) => const UnlockPage(),
  ),
  StatefulShellRoute.indexedStack(
    builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) {
      return GuardianShell(navigationShell: shell);
    },
    branches: <StatefulShellBranch>[
      StatefulShellBranch(routes: dashboardRoutes),
      StatefulShellBranch(routes: rulesRoutes),
      StatefulShellBranch(routes: reportsRoutes),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: GuardianPaths.alerts,
            builder: (BuildContext context, GoRouterState state) => const AlertsCenterPage(),
            routes: <RouteBase>[
              GoRoute(
                path: 'preferences',
                builder: (BuildContext context, GoRouterState state) {
                  return const NotificationPrefsPage();
                },
              ),
              GoRoute(
                path: 'time-requests',
                builder: (BuildContext context, GoRouterState state) => const TimeRequestsPage(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: GuardianPaths.more,
            builder: (BuildContext context, GoRouterState state) => const MorePage(),
            routes: <RouteBase>[
              GoRoute(
                path: 'account',
                builder: (BuildContext context, GoRouterState state) => const AccountPage(),
              ),
              GoRoute(
                path: 'sessions',
                builder: (BuildContext context, GoRouterState state) => const SessionsPage(),
              ),
              GoRoute(
                path: 'security',
                builder: (BuildContext context, GoRouterState state) => const SecurityPage(),
              ),
              GoRoute(
                path: 'privacy',
                builder: (BuildContext context, GoRouterState state) => const PrivacyPage(),
              ),
              GoRoute(
                path: 'audit',
                builder: (BuildContext context, GoRouterState state) => const AuditLogPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: GuardianPaths.pairing,
    builder: (BuildContext context, GoRouterState state) => const PairingPage(),
  ),
  GoRoute(
    path: GuardianPaths.devices,
    builder: (BuildContext context, GoRouterState state) => const DevicesPage(),
    routes: <RouteBase>[
      GoRoute(
        path: ':deviceId',
        builder: (BuildContext context, GoRouterState state) {
          return DeviceDetailPage(deviceId: state.pathParameters['deviceId'] ?? '');
        },
      ),
    ],
  ),
];

/// Redirecionamento dentro da area do responsavel (sessao, bloqueio do app). Chamado pelo
/// roteador so quando o modo e responsavel e o destino ja esta sob [GuardianPaths.root].
String? guardianRedirect(Ref ref, GoRouterState state) {
  final String location = state.matchedLocation;
  final GuardianSession session = ref.read(guardianSessionProvider);
  switch (session) {
    case GuardianSignedOut():
      return _signedOutLocations.contains(location) ? null : GuardianPaths.signIn;
    case GuardianLocked():
      // Bloqueado, so a tela de bloqueio e a recuperacao de acesso ficam alcancaveis.
      if (location == GuardianPaths.unlock || location == GuardianPaths.recover) {
        return null;
      }
      if (location != GuardianPaths.root && !_accountLocations.contains(location)) {
        ref.read(guardianReturnLocationProvider).remember(state.uri.toString());
      }
      return GuardianPaths.unlock;
    case GuardianReady(:final String? pendingRecoveryKey):
      if (pendingRecoveryKey != null) {
        return location == GuardianPaths.recoveryKey ? null : GuardianPaths.recoveryKey;
      }
      if (location == GuardianPaths.root || _accountLocations.contains(location)) {
        // Depois de desbloquear, volta para onde a pessoa estava.
        return ref.read(guardianReturnLocationProvider).take() ?? GuardianPaths.home;
      }
      return null;
  }
}

/// Registra o que deve fazer o roteador reavaliar os redirecionamentos desta area.
void registerGuardianRouterRefresh(Ref ref, void Function() refresh) {
  ref.listen<GuardianSession>(guardianSessionProvider, (
    GuardianSession? previous,
    GuardianSession next,
  ) {
    refresh();
  });
}
