import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../guardian_paths.dart';
import 'presentation/dashboard_page.dart';

/// Rotas da aba "Painel". A primeira rota e a raiz da aba (`GuardianPaths.home`).
final List<RouteBase> dashboardRoutes = <RouteBase>[
  GoRoute(
    path: GuardianPaths.home,
    builder: (BuildContext context, GoRouterState state) => const DashboardPage(),
  ),
];
