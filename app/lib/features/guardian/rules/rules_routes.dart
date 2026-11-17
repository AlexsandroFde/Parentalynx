import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../apps/domain/app_entry.dart';
import '../guardian_paths.dart';
import 'presentation/allowed_hours_page.dart';
import 'presentation/apps_rules_page.dart';
import 'presentation/block_periods_page.dart';
import 'presentation/daily_limit_page.dart';
import 'presentation/exceptions_page.dart';
import 'presentation/protection_page.dart';
import 'presentation/rules_overview_page.dart';
import 'presentation/web_rules_page.dart';

/// Rotas da aba "Regras". A primeira rota e a raiz da aba (`GuardianPaths.rules`). As demais
/// ficam abaixo dela.
final List<RouteBase> rulesRoutes = <RouteBase>[
  GoRoute(
    path: GuardianPaths.rules,
    builder: (BuildContext context, GoRouterState state) => const RulesOverviewPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'limit',
        builder: (BuildContext context, GoRouterState state) => const DailyLimitPage(),
      ),
      GoRoute(
        path: 'hours',
        builder: (BuildContext context, GoRouterState state) => const AllowedHoursPage(),
      ),
      GoRoute(
        path: 'periods',
        builder: (BuildContext context, GoRouterState state) => const BlockPeriodsPage(),
      ),
      GoRoute(
        path: 'apps',
        builder: (BuildContext context, GoRouterState state) {
          final String? category = state.uri.queryParameters['category'];
          return AppsRulesPage(
            initialCategory: category == null ? null : AppCategory.parse(category),
          );
        },
      ),
      GoRoute(
        path: 'exceptions',
        builder: (BuildContext context, GoRouterState state) => const ExceptionsPage(),
      ),
      GoRoute(
        path: 'web',
        builder: (BuildContext context, GoRouterState state) => const WebRulesPage(),
      ),
      GoRoute(
        path: 'protection',
        builder: (BuildContext context, GoRouterState state) => const ProtectionPage(),
      ),
    ],
  ),
];
