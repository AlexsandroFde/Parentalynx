import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../guardian_paths.dart';
import 'presentation/activity_pages.dart';
import 'presentation/reports_page.dart';

/// Rotas da aba "Relatórios". A primeira rota e a raiz da aba (`GuardianPaths.reports`). As
/// demais ficam abaixo dela.
final List<RouteBase> reportsRoutes = <RouteBase>[
  GoRoute(
    path: GuardianPaths.reports,
    builder: (BuildContext context, GoRouterState state) => const ReportsPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'sessions',
        builder: (BuildContext context, GoRouterState state) {
          return SessionsPage(initialDay: state.uri.queryParameters['day']);
        },
      ),
      GoRoute(
        path: 'events',
        builder: (BuildContext context, GoRouterState state) {
          return EventsPage(
            from: state.uri.queryParameters['from'],
            to: state.uri.queryParameters['to'],
          );
        },
      ),
      GoRoute(
        path: 'browsing',
        builder: (BuildContext context, GoRouterState state) {
          return BrowsingPage(
            from: state.uri.queryParameters['from'],
            to: state.uri.queryParameters['to'],
          );
        },
      ),
    ],
  ),
];
